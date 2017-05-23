import Foundation
import XCTest
import MongoKitten
import Configuration
import SwiftyJSON
import Dispatch

@testable import Routers
import ResourceManager
import Models
import Common

class FacebookTests: XCTestCase {
    static var database: MongoKitten.Database! = nil
    
    /// Facebook 使用者權杖
    static var facebookAccessTokens: [String] = []
    
    /// PKServer 權杖
    static var parkingAccessTokens: [String] = []
    
    /// Retrieves Test Users and Database Settings
    override class func setUp() {
        FacebookTests.database = try! createTestDatabaseAndResourceManager()
        
        // MARK: 從 Facebook 取得測試使用者資料
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        
        guard var urlBuilder = URLComponents(string: "https://graph.facebook.com/oauth/access_token") else {
            XCTFail("Failed to create URL that will be used to retrieve app access token")
            return
        }
        
        let facebookAppId = PKResourceManager.shared.config.facebookAppId
        let facebookAppSecret = PKResourceManager.shared.config.facebookSecret
        
        urlBuilder.queryItems = [ URLQueryItem(name: "client_id", value: facebookAppId),
                                  URLQueryItem(name: "client_secret", value: facebookAppSecret),
                                  URLQueryItem(name: "grant_type", value: "client_credentials") ]
        
        guard let url = urlBuilder.url else {
            XCTFail("Failed to create URL that will be used to retrieve app access token")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            switch (data, error) {
            case (_, .some(let error)):
                XCTFail("Request to retrieve test users failed: \(error.localizedDescription)")
            case (.some(let responseData), _):
                let response = JSON(data: responseData)
                if let appAccessToken = response["access_token"].string {
                    guard var urlBuilder = URLComponents(string: "https://graph.facebook.com/v2.9/\(facebookAppId)/accounts/test-users") else {
                        XCTFail("Failed to create URL that will be used to retrieve test users")
                        return
                    }
                    urlBuilder.queryItems = [ URLQueryItem(name: "access_token", value: appAccessToken) ]
                    
                    guard let url = urlBuilder.url else {
                        XCTFail("Failed to create URL that will be used to retrieve test users")
                        return
                    }
                    
                    URLSession.shared.dataTask(with: url) { data, _, error in
                        switch (data, error) {
                        case (_, .some(let error)):
                            XCTFail("Request to retrieve test users failed: \(error.localizedDescription)")
                        case (.some(let responseData), _):
                            let response = JSON(data: responseData)
                            if let testUsers = response["data"].array {
                                for testUser in testUsers {
                                    if let token = testUser["access_token"].string {
                                        self.facebookAccessTokens.append(token)
                                    } else {
                                        XCTFail("Error reading facebook response schema.")
                                        break
                                    }
                                }
                            } else {
                                XCTFail("Error reading facebook response schema.")
                                break
                            }
                        default:
                            XCTFail("Unknown response state.")
                        }
                        
                        dispatchGroup.leave()
                        }.resume()
                } else {
                    XCTFail("Error reading facebook response schema.")
                    break
                }
            default:
                XCTFail("Unknown response state.")
            }
        }.resume()
        
        // 10 seconds is plentiful for a simple request
        _ = dispatchGroup.wait(timeout: DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 10_000_000_000))
    }
    
    override class func tearDown() {
        do {
            try database["users"].drop()
        } catch {
            XCTFail("復原資料庫")
        }
    }
    
    /**
     # 測試範圍
     
     1. 先註冊新的使用者，檢查資料庫是否有該使用者（以登入代幣以及臉書權杖驗證）
     2. 之後再登入一次，檢查得到的代幣是否對應到同一個使用者（以 `ObjectId` 驗證）
    */
    func test1_StandardRegisterAndLoginFlow() {
        FacebookTests.parkingAccessTokens = FacebookTests.facebookAccessTokens.map { _ in "" }
        
        let expectations = FacebookTests.facebookAccessTokens.enumerated().map { expectation(description: "Finished flow for user \($0.offset)") }
        
        for (index, user) in FacebookTests.facebookAccessTokens.enumerated() {
            let facebookToken = user
            
            // 1.1 註冊
            AuthActions.registerOrLogin(strategy: .facebook, userId: nil, token: facebookToken, scope: .standard) { json, error in
                // 1.1.1 沒有錯誤
                XCTAssertNil(error)
                
                // 1.1.2 收到 PKServer 的登入代幣
                guard let token = json?.string else {
                    XCTFail()
                    return
                }
                
                // 1.2 找到資料庫中的使用者
                // 1.2.1 用登入代幣來找
                guard let user = self.getUser(withLogin: token) else {
                    XCTFail("Either the document is not found or a problem occured within MongoKitten.")
                    return
                }
                
                // 1.2.2 檢查臉書權杖
                let tokenExist = user.strategies.contains { $0.strategy == .facebook && $0.accessToken == facebookToken }
                XCTAssert(tokenExist, "The registered token does not exist in document")
                
                // 1.3 紀錄 PKServer 的使用者 ID
                let userObjectId = user._id!
                
                // 2.1 重新登入
                AuthActions.registerOrLogin(strategy: .facebook, userId: nil, token: facebookToken, scope: .standard) { json, error in
                    XCTAssertNil(error)
                    
                    guard let token = json?.string else {
                        XCTFail()
                        return
                    }
                    
                    guard let user = self.getUser(withLogin: token) else {
                            XCTFail("Either the document is not found or a problem occured within MongoKitten.")
                            return
                    }
                    
                    // 2.1.1 應該有一樣的 PKServer 使用者 ID
                    XCTAssertEqual(userObjectId, user._id!)
                    FacebookTests.parkingAccessTokens[index] = token
                    
                    expectations[index].fulfill()
                }
            }
        }
        
        wait(for: expectations, timeout: 10.0)
    }
    
    /**
     # 測試範圍
     
     1. 將使用者 1, 3, 4 移除
     2. 檢查使用者是否還在資料庫中
     
     */
    func test2_RemoveUser() {
        let expectations = [1, 3, 4].map({ expectation(description: "Deleting user \($0)") })
        
        for (expectationIndex, userIndex) in [1, 3, 4].enumerated() {
            let parkingAccessToken = FacebookTests.parkingAccessTokens[userIndex]
            
            // 先取得使用者 ID
            guard let user = getUser(withLogin: parkingAccessToken) else {
                XCTFail("Cannot retrieve user from database.")
                    return
            }
            
            let userObjectId = user._id!
            
            MeActions.delete(user: user) { _, error in
                XCTAssertNil(error)
                
                // 資料庫
                do {
                    let user = try FacebookTests.database["users"].findOne("_id" == userObjectId)
                    // 刪除後不應該存在
                    XCTAssertNil(user)
                    
                    expectations[expectationIndex].fulfill()
                } catch {
                    XCTFail("Database error.")
                }
            }
        }
        
        wait(for: expectations, timeout: 10.0)
    }
    
    func test3_AddStrategies() {
        // 將 Facebook 權杖 1 給 0；將 Facebook 權杖 3, 4 給 2
        // 從 PKServer 的權杖來看，0 應該要有 2 個 Strategies（0, 1）；2 應該要有 3 個 Strategies（2, 3, 4）
        
        let expectations = [0, 2].map({ expectation(description: "Add strategies to user \($0)") })
        
        let work = [(target: 0, sources: [1]), (target: 2, sources: [3, 4])]
        
        for (expectationIndex, (target: target, sources: sources)) in work.enumerated() {
            var expectedTokens = [FacebookTests.facebookAccessTokens[target]]
            for addingToken in sources.map({ FacebookTests.facebookAccessTokens[$0] }) {
                expectedTokens.append(addingToken)
            }
            
            let userAccessToken = FacebookTests.parkingAccessTokens[target]
            var currentDoneIndex = -1
            
            var callback: ((JSON?, PKServerError?) -> Void)? = nil
            callback = { (_: JSON?, error: PKServerError?) -> Void in
                if error != nil {
                    XCTFail("Cannot add Strategies, error from AuthActions")
                }
                
                // 取得 User
                guard let user = self.getUser(withLogin: userAccessToken) else {
                    XCTFail("Failed to retrieve user to test")
                    return
                }
                
                currentDoneIndex += 1
                if currentDoneIndex == sources.count {
                    XCTAssert(expectedTokens.elementsEqual(user.strategies.map({ $0.accessToken })))
                    expectations[expectationIndex].fulfill()
                    return
                }
                
                // 下一次 AuthActions！
                MeActions.add(strategy: .facebook, userId: nil, token: FacebookTests.facebookAccessTokens[sources[currentDoneIndex]], to: user, completionHandler: callback!)
            }
            
            // 開始連鎖反應
            callback!(nil, nil)
        }
        
        wait(for: expectations, timeout: 10.0)
    }
    
    func test4_AddRedundantStrategies() {
        guard let user = getUser(withLogin: FacebookTests.parkingAccessTokens[0]) else {
            XCTFail()
            return
        }
        
        let redudantStrategyExpectation = expectation(description: "Redundant Strategies should throw error!")
        
        MeActions.add(strategy: .facebook, userId: nil, token: FacebookTests.facebookAccessTokens[4], to: user) { _, error in
            // Must throw an error!
            XCTAssertNotNil(error)
            
            redudantStrategyExpectation.fulfill()
        }
        
        wait(for: [redudantStrategyExpectation], timeout: 10.0)
    }
    
    func test5_RemoveStrategies() {
        // Try to remove strategy 0 from user 0
        guard let user = getUser(withLogin: FacebookTests.parkingAccessTokens[0]) else {
            XCTFail()
            return
        }
        
        let facebookId = user.strategies[0].userId
        let removeStrategyExpectation = expectation(description: "User strategy removal")
        
        MeActions.remove(strategy: .facebook, userId: facebookId, from: user) { _, error in
            XCTAssertNil(error)
            
            // Retrieve user again!
            guard let user = self.getUser(withLogin: FacebookTests.parkingAccessTokens[0]) else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(user.strategies.count, 1)
            
            removeStrategyExpectation.fulfill()
        }
        
        wait(for: [removeStrategyExpectation], timeout: 10.0)
    }
    
    func test6_RemoveLastStrategy() {
        // Try to remove strategy 0 from user 0
        guard let user = getUser(withLogin: FacebookTests.parkingAccessTokens[0]) else {
            XCTFail()
            return
        }
        
        let facebookId = user.strategies[0].userId
        let removeStrategyExpectation = expectation(description: "User strategy removal")
        
        MeActions.remove(strategy: .facebook, userId: facebookId, from: user) { _, error in
            XCTAssertNotNil(error)
            
            // Retrieve user again!
            guard let user = self.getUser(withLogin: FacebookTests.parkingAccessTokens[0]) else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(user.strategies.count, 1)
            
            removeStrategyExpectation.fulfill()
        }
        
        wait(for: [removeStrategyExpectation], timeout: 10.0)
    }
    
    
    func queryForUser(with token: String) -> Query {
        return [ "tokens": [ "$elemMatch": [ "value": token ] ] ]
    }
    func getUser(withLogin token: String) -> PKUser? {
        guard let userDocumentOptional = try? FacebookTests.database["users"].findOne(queryForUser(with: token)) else {
            return nil
        }
        if let userDocument = userDocumentOptional {
            return PKUser.deserialize(from: userDocument)
        }
        
        return nil
    }
    func getUser(withId id: ObjectId) -> PKUser? {
        guard let userDocumentOptional = try? FacebookTests.database["users"].findOne("_id" == id) else {
            return nil
        }
        if let userDocument = userDocumentOptional {
            return PKUser.deserialize(from: userDocument)
        }
        
        return nil
    }
}

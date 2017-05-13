import Foundation
import XCTest
import MongoKitten
import Configuration
import SwiftyJSON

@testable import Routers

class FacebookTests: XCTestCase {
    var database: MongoKitten.Database! = nil
    var testUsers: [String] = []
    
    override func setUp() {
        // MARK: 從資料庫載入設定
        let configurationManager = ConfigurationManager()
        configurationManager.load(file: "./../../config.json")
        
        guard let configs = configurationManager.getConfigs() as? [String: Any],
            let mongodb = configs["mongodb"] as? [String: Any],
            let mongodbHost = mongodb["host"] as? String,
            let mongodbPort = mongodb["port"] as? UInt16,
            let facebook = configs["facebook"] as? [String: String],
            let facebookAppId = facebook["appId"],
            let facebookAppSecret = facebook["secret"] else {
                XCTFail("No configuration found.")
                return
        }
        
        let mongodbSettings = ClientSettings(host: MongoHost(hostname: mongodbHost, port: mongodbPort), sslSettings: nil, credentials: nil)
        guard let server = try? MongoKitten.Server(mongodbSettings) else {
            XCTFail("Connection to MongoDB failed.")
            return
        }
        
        let number = arc4random()
        database = server["__\(number)__parking_unit_test"]
        
        // MARK: 從 Facebook 取得測試使用者資料
        let retrievedExpectation = expectation(description: "Retrieving test users")
        
        guard var urlBuilder = URLComponents(string: "https://graph.facebook.com/oauth/access_token") else {
            XCTFail("Failed to create URL that will be used to retrieve app access token")
            return
        }
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
                                        self.testUsers.append(token)
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
                        
                        retrievedExpectation.fulfill()
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
        wait(for: [retrievedExpectation], timeout: 10.0)
    }
    
    override func tearDown() {
        print(testUsers)
        
        do {
            try database.drop()
        } catch {
            XCTFail("Test database cannot be dropped, database name: \(database.name)")
        }
    }
    
    func testRegisterAndLoginFlow() {
        
    }
}

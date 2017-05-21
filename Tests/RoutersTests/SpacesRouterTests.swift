import XCTest
import Dispatch
import MongoKitten
import Models
import CoreLocation
@testable import Routers

class SpacesRouterTests: XCTestCase {
    static var database: Database!
    static var testProvider: ObjectId!
    static var firstSpaceId: ObjectId!
    
    var database: Database {
        return SpacesRouterTests.database
    }
    
    let coordinates = [
        (latitude: 1.0, longitude: 1.0),
        (latitude: 1.0025, longitude: 1.0025),
        (latitude: 1.005, longitude: 1.005),
        (latitude: 1.01, longitude: 1.01),
        (latitude: 1.0125, longitude: 1.0125),
        (latitude: 1.015, longitude: 1.015),
        (latitude: 1.0501, longitude: 1.0801),
        (latitude: 1.0501, longitude: 1.0805),
        (latitude: 1.0501, longitude: 1.0901),
        (latitude: 1.0501, longitude: 1.0905),
        (latitude: 1.0506, longitude: 1.0801),
        (latitude: 1.0601, longitude: 1.0801),
        (latitude: 1.0606, longitude: 1.0801),
        (latitude: 1.0701, longitude: 1.0801),
        (latitude: 1.0706, longitude: 1.0801),
        (latitude: 1.1, longitude: 1.1)
    ]
    
    override class func setUp() {
        database = try! createTestDatabaseAndResourceManager()
        guard let created = try? createProvider() else {
            XCTFail("Failed to create a provider to host the spaces.")
            return
        }
        
        testProvider = created
    }
    override class func tearDown() {
        do {
            try database["providers"].drop()
            try database["spaces"].drop()
        } catch {
            XCTFail("復原資料庫")
        }
    }
    
    func test1_CreateSpaces() {
        let creationConfirmed = expectation(description: "創造一個車位")
        let createdAdditional = expectation(description: "創造測試車位")
        
        createdAdditional.expectedFulfillmentCount = 15
        
        SpacesActions.create(latitude: 1.0, longitude: 1.0, markings: "DGS-1100", charge: 50.0, unitTime: 60.0, providerId: SpacesRouterTests.testProvider) { id, error in
            XCTAssertNil(error, "在 SpacesAction.create(latitude:longtitude:markings:charge:unitTime:providerId:completionHandler:) 的回呼中發生錯誤")
            XCTAssertNotNil(id, "在 SpacesAction.create(latitude:longtitude:markings:charge:unitTime:providerId:completionHandler:) 的回呼中沒有結果")
            
            guard let retrievedResult = try? database["spaces"].findOne("_id" == ObjectId(id!)),
                  let insertedDocument = retrievedResult else {
                XCTFail("無法取得插入在 MongoDB 中的文件")
                return
            }
            
            guard let space = PKSpace.deserialize(from: insertedDocument) else {
                XCTFail("無法將 MongoDB 中的文件反序列為 Swift 結構")
                return
            }
            
            XCTAssertEqualWithAccuracy(space.location.latitude, 1.0, accuracy: 0.00001)
            XCTAssertEqualWithAccuracy(space.location.longitude, 1.0, accuracy: 0.00001)
            XCTAssertEqual(space.markings, "DGS-1100")
            XCTAssertEqualWithAccuracy(space.fee.charge, 50.0, accuracy: 0.0001)
            XCTAssertEqualWithAccuracy(space.fee.unitTime, 60.0, accuracy: 0.001)
            XCTAssertEqual(space.provider._id, SpacesRouterTests.testProvider!)
            
            SpacesRouterTests.firstSpaceId = try! ObjectId(id!)
            
            creationConfirmed.fulfill()
        }
        
        for (index, coordinate) in coordinates.enumerated() where index != 0 {
            let latitude = coordinate.latitude
            let longitude = coordinate.longitude
            
            SpacesActions.create(latitude: latitude, longitude: longitude, markings: "DGS-11\(index)", charge: 50.0, unitTime: 60.0, providerId: SpacesRouterTests.testProvider) { id, error in
                XCTAssertNil(error, "在 SpacesAction.create(latitude:longtitude:markings:charge:unitTime:providerId:completionHandler:) 的回呼中發生錯誤")
                XCTAssertNotNil(id, "在 SpacesAction.create(latitude:longtitude:markings:charge:unitTime:providerId:completionHandler:) 的回呼中沒有結果")
                createdAdditional.fulfill()
            }
        }
        
        wait(for: [creationConfirmed, createdAdditional], timeout: 10.0)
    }
    
    func test2_ReadIndividualSpace() {
        let read = expectation(description: "測試讀取")
        
        SpacesActions.read(id: SpacesRouterTests.firstSpaceId) { json, error in
            XCTAssertNil(error, "SpacesActions.read(id:completionHandler:) 的回呼發生錯誤")
            guard let json = json else {
                XCTFail("SpacesActions.read(id:completionHandler:) 沒有帶回 JSON 資料")
                return
            }
            
            XCTAssertEqual(json["_id"].stringValue, SpacesRouterTests.firstSpaceId.hexString)
            XCTAssertEqual(json["providerId"].stringValue, SpacesRouterTests.testProvider.hexString)
            XCTAssertEqual(json["location"]["latitude"].doubleValue, 1.0)
            XCTAssertEqual(json["location"]["longitude"].doubleValue, 1.0)
            XCTAssertEqual(json["markings"].stringValue, "DGS-1100")
            XCTAssertEqual(json["fee"]["charge"].doubleValue, 50.0)
            XCTAssertEqual(json["fee"]["unitTime"].doubleValue, 60.0)
            
            read.fulfill()
        }
        
        wait(for: [read], timeout: 10.0)
    }
    
    func test3_ReadSpacesInGrid() {
        let readFirst = expectation(description: "測試讀取 1")
        
        SpacesActions.read(in: "1.00-1.01:1.00-1.05") { json, error in
            XCTAssertNil(error, "SpacesActions.read(in:completionHandler:) 發生錯誤")
            
            let array = json!.arrayValue
            let count = coordinates.reduce(0) { (count, next) -> Int in
                let this: Int = (next.latitude >= 1.00 && next.latitude < 1.01 && next.longitude >= 1.00 && next.longitude < 1.05) ? 1 : 0
                return count + this
            }
            
            XCTAssertEqual(array.count, count)
            
            readFirst.fulfill()
        }
        
        let readSecond = expectation(description: "測試讀取 2")
        
        SpacesActions.read(in: "1.00-1.01:1.01-1.03,1.05-1.07:1.02-1.09") { json, error in
            XCTAssertNil(error, "SpacesActions.read(in:completionHandler:) 發生錯誤")
            
            let array = json!.arrayValue
            let count = coordinates.reduce(0) { (count, next) -> Int in
                let condition1: Bool = (next.latitude >= 1.00 && next.latitude < 1.01 && next.longitude >= 1.01 && next.longitude < 1.03)
                let condition2: Bool = (next.latitude >= 1.05 && next.latitude < 1.07 && next.longitude >= 1.02 && next.longitude < 1.09)
                return count + ((condition1 || condition2) ? 1 : 0)
            }
            
            XCTAssertEqual(array.count, count)
            
            readSecond.fulfill()
        }
        
        wait(for: [readFirst, readSecond], timeout: 10.0)
    }
    
    func test4_UpdateSpace() {
        let updated = expectation(description: "更新完成")
        
        // 取得隨便一個
        SpacesActions.read(in: "1.00-1.01:1.00-1.05") { json, error in
            XCTAssertNil(error, "SpacesActions.read(in:completionHandler:) 發生錯誤")
            let array = json!.arrayValue
            let spaceId = try! ObjectId(array[0]["_id"].stringValue)
            
            SpacesActions.update(id: spaceId, with: ["markings": "XT-010"]) { error in
                XCTAssertNil(error)
                SpacesActions.read(id: spaceId) { json, error in
                    XCTAssertNil(error)
                    
                    XCTAssertEqual(json!["_id"].stringValue, spaceId.hexString)
                    XCTAssertEqual(json!["markings"].stringValue, "XT-010")
                    
                    updated.fulfill()
                }
            }
        }
        
        wait(for: [updated], timeout: 10.0)
    }
    
    func test5_DeleteSpace() {
        let deleted = expectation(description: "成功刪除")
        
        // 取得隨便一個
        SpacesActions.read(in: "1.00-1.01:1.00-1.05") { json, error in
            XCTAssertNil(error, "SpacesActions.read(in:completionHandler:) 發生錯誤")
            let array = json!.arrayValue
            let spaceId = try! ObjectId(array[0]["_id"].stringValue)
            
            SpacesActions.delete(id: spaceId) { error in
                XCTAssertNil(error)
                SpacesActions.read(id: spaceId) { json, error in
                    XCTAssertNotNil(error)
                    
                    deleted.fulfill()
                }
            }
        }
        
        wait(for: [deleted], timeout: 10.0)
    }
    
    func test6_CreateSpaceWithoutBelongingProvider() {
        let created = expectation(description: "成功刪除")
        SpacesActions.create(latitude: 5.0, longitude: 5.0, markings: "DGX-0101", charge: 50.0, unitTime: 60.0, providerId: ObjectId()) { _, error in
            XCTAssertNotNil(error)
            created.fulfill()
        }
        wait(for: [created], timeout: 10.0)
    }
    
    // MARK: 輔助方法
    class func createProvider() throws -> ObjectId {
        let dispatchGroup = DispatchGroup()
        
        var providerId: ObjectId? = nil
        
        dispatchGroup.enter()
        
        ProviderActions.create(name: "Example Provider", type: .government) { id, error in
            providerId = id == nil ? nil : try? ObjectId(id!)
            dispatchGroup.leave()
        }
        
        let timeout = timespec(tv_sec: 10, tv_nsec: 0)
        let wall = DispatchWallTime(timespec: timeout)
        
        switch dispatchGroup.wait(wallTimeout: wall) {
        case .success:
            if let id = providerId {
                return id
            } else {
                fallthrough
            }
        case .timedOut:
            throw NSError(domain: "", code: -1, userInfo: nil)
        }
    }
}

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

class ProvidersRouterTests: XCTestCase {
    static var providerId: ObjectId!
    static var spaceId: ObjectId!
    static var database: MongoKitten.Database! = nil
    
    override class func setUp() {
        ProvidersRouterTests.database = try! createTestDatabaseAndResourceManager()
    }
    
    override class func tearDown() {
        do {
            try database["providers"].drop()
            try database["spaces"].drop()
        } catch {
            XCTFail("復原資料庫")
        }
    }
    
    func test1_CreateProvider() {
        let collection = ProvidersRouterTests.database["providers"]
        let created = expectation(description: "")
        
        ProviderActions.create(name: "Example Provider", type: .government) { id, error in
            XCTAssertNil(error)
            XCTAssertNotNil(id)
            
            let documentId = try! ObjectId(id!)
            
            // 1. 必須在資料庫中存在
            do {
                let document = try collection.findOne("_id" == documentId)
                XCTAssertNotNil(document)
            } catch {
                XCTFail()
            }
            ProvidersRouterTests.providerId = documentId
            
            // 2. 必須有正確的 detailedJSON
            ProviderActions.read(id: documentId) { json, error in
                XCTAssertNil(error)
                XCTAssertNotNil(json)
                
                guard let json = json else { return }
                
                XCTAssertEqual(json["_id"].stringValue, id!)
                XCTAssertEqual(json["type"].stringValue, "government")
                XCTAssertEqual(json["name"].stringValue, "Example Provider")
                
                created.fulfill()
            }
        }
        
        wait(for: [created], timeout: 10.0)
    }
    
    func test2_UpdateProvider() {
        let updated = expectation(description: "")
        
        let id: ObjectId = ProvidersRouterTests.providerId!
        let update: JSON = [
            "name": "彰化市政府",
            "contactInformation": [
                "phone": "044759993",
                "email": "transport@changhua.gov.tw"
            ]
        ]
        ProviderActions.update(id: id, update: update, by: PKTokenScope.agent(provider: id)) { error in
            XCTAssertNil(error)
            ProviderActions.read(id: id) { json, error in
                XCTAssertNil(error)
                XCTAssertNotNil(json)
                
                guard let json = json else { return }
                
                XCTAssertEqual(json["_id"].stringValue, id.hexString)
                XCTAssertEqual(json["type"].stringValue, "government")
                XCTAssertEqual(json["name"].stringValue, "彰化市政府")
                
                XCTAssertEqual(json["contactInformation"]["phone"], "044759993")
                XCTAssertEqual(json["contactInformation"]["email"], "transport@changhua.gov.tw")
                
                updated.fulfill()
            }
        }
        
        wait(for: [updated], timeout: 10.0)
    }
    
    func test3_CreateSpaceUnderProvider() {
        let created = expectation(description: "創造提供者下的車位")
        
        SpacesActions.create(latitude: 1.0, longitude: 1.0, markings: "DGS-210", charge: 5.0, unitTime: 10.0, providerId: ProvidersRouterTests.providerId!) { result, error in
            XCTAssertNil(error)
            XCTAssertNotNil(result)
            
            let spaceId = result!
            
            ProviderActions.readSpaces(in: ProvidersRouterTests.providerId!) { result, error in
                XCTAssertNil(error)
                XCTAssertNotNil(result)
                
                guard let spaces = result?.arrayValue else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(spaces.count, 1)
                
                let first = spaces.first!
                
                XCTAssertEqual(first["_id"].stringValue, spaceId)
                
                ProvidersRouterTests.spaceId = try! ObjectId(first["_id"].stringValue)
                
                created.fulfill()
            }
        }
        
        wait(for: [created], timeout: 10.0)
    }
    
    func test4_DeleteProviderWithSpace() {
        let deleted = expectation(description: "刪除有車位的提供者")
        ProviderActions.delete(id: ProvidersRouterTests.providerId) { error in
            XCTAssertNotNil(error)
            deleted.fulfill()
        }
        
        wait(for: [deleted], timeout: 10.0)
    }
    
    func test5_DeleteProviderWithoutSpace() {
        let deleted = expectation(description: "刪除有車位的提供者")
        
        SpacesActions.delete(id: ProvidersRouterTests.spaceId) { error in
            XCTAssertNil(error)
            ProviderActions.delete(id: ProvidersRouterTests.providerId) { error in
                XCTAssertNil(error)
                deleted.fulfill()
            }
        }
        
        wait(for: [deleted], timeout: 10.0)
    }
}

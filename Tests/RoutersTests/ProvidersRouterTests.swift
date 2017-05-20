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
    static var database: MongoKitten.Database! = nil
    
    override class func setUp() {
        ProvidersRouterTests.database = try! createTestDatabaseAndResourceManager()
//        
//        // Create fake user!
//        let Users = database["users"]
//        let user: Document = [
//            "deviceIds": [],
//            "links": [],
//            "tokens": [
//                [ "issued": Date(), "value": "test_token", "scope": [ "case": "admin" ] ]
//            ],
//            "types": [
//                [ "case": "standard" ],
//                [ "case": "admin", "values": [ "readWrite" ] ]
//            ]
//        ]
//        
//        do {
//            try Users.insert(user)
//        } catch {
//            XCTFail()
//        }
    }
    
    /// Drops Database
    override class func tearDown() {
        do {
            try ProvidersRouterTests.database.drop()
        } catch {
            XCTFail("Test database cannot be dropped, database name: \(database.name)")
        }
    }
    
    func test1_CreateProvider() {
        let created = expectation(description: "")
        ProviderActions.create(name: "Example Provider", type: .government) { id, error in
            XCTAssertNil(error)
            XCTAssertNotNil(id)
            
            let documentId = try! ObjectId(id!)
            
            // 1. 必須在資料庫中存在
            XCTAssertNotNil(try! ProvidersRouterTests.database["providers"].findOne("_id" == documentId))
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
}

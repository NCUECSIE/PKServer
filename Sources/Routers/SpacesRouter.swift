import Kitura
import KituraNet
import MongoKitten
import SwiftyJSON
import LoggerAPI

import Common
import Models
import ResourceManager
import Utilities

internal struct SpacesActions {
    static func create(latitude: Double, longitude: Double, markings: String,
                       charge: Double, span: Double, providerId: ObjectId,
                       completionHandler: (_ insertedId: ObjectId?, _ error: PKServerError?) -> Void) {
        let Providers = PKResourceManager.shared.database["providers"]
        let collection = PKResourceManager.shared.database["spaces"]
        let space = PKSpace(provider: providerId, latitude: latitude, longitude: longitude, markings: markings, fee: Fee(span: span, charge: charge))
        
        // 檢查 Provider 是否存在
        do {
            if try Providers.findOne("_id" == providerId) == nil {
                // 沒有找到
                completionHandler(nil, PKServerError.notFound)
            }
        } catch {
            completionHandler(nil, PKServerError.database(while: "checking if the provider exist"))
        }
        
        do {
            let primitive = try collection.insert(Document(space))
            guard let insertedId = primitive.to(ObjectId.self) else {
                completionHandler(nil, PKServerError.deserialization(data: "ObjectId", while: "reading response from MongoKitten"))
                return
            }
            completionHandler(insertedId, nil)
        } catch {
            completionHandler(nil, PKServerError.database(while: "inserting new document"))
        }
    }
    
    static func read(in grid: NonConsecutiveGrids, completionHandler: (_ json: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["spaces"]
        
        
        let gridsQuery = [
            "$or": grid.consecutiveGrids.map({ consecutiveGrid -> Query in
                [
                    "$and": [
                        [ "longitude": [ "$gte":  consecutiveGrid.lowerLeft.longitude ] ],
                        [ "longitude": [ "$lt": consecutiveGrid.upperRight.longitude ] ],
                        [ "latitude": [ "$gte": consecutiveGrid.lowerLeft.latitude ] ],
                        [ "latitude": [ "$lt": consecutiveGrid.lowerLeft.latitude ] ]
                    ]
                ]
            })
        ] as Query
        
        do {
            var hasDeserializeError = false
            let spaces = try collection.find(gridsQuery).map({ (document: Document) -> PKSpace in
                guard let space = PKSpace.deserialize(from: document) else {
                    hasDeserializeError = true
                    return PKSpace(provider: ObjectId(0)!, latitude: 0.0, longitude: 0.0, markings: "", fee: Fee(span: 0, charge: 0))
                }
                return space
            })
            
            if hasDeserializeError {
                completionHandler(nil, PKServerError.deserialization(data: "Space", while: "deserializing BSON documents to Swift structures"))
            } else {
                let payload = spaces.map { $0.simpleJSON }
                
                completionHandler(JSON(payload), nil)
            }
        } catch {
            completionHandler(nil, .database(while: "reading all documents in a collection"))
        }
        
        
    }
    
    static func read(id: ObjectId, completionHandler: (_ json: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["spaces"]
        
        do {
            guard let document = try collection.findOne("_id" == id) else {
                completionHandler(nil, PKServerError.notFound)
                return
            }
            
            if let space = document.to(PKSpace.self) {
                completionHandler(space.detailedJSON, nil)
            } else {
                completionHandler(nil, PKServerError.deserialization(data: "Space", while: "deserializing from database"))
            }
        } catch {
            completionHandler(nil, PKServerError.database(while: "reading a space"))
        }
    }
    
    static func update(id: ObjectId, with json: JSON, completionHandler: (_ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["spaces"]
        var space: PKSpace! = nil
        
        do {
            guard let document = try collection.findOne("_id" == id) else {
                completionHandler(PKServerError.notFound)
                return
            }
            if let s = document.to(PKSpace.self) {
                space = s
            } else {
                completionHandler(PKServerError.deserialization(data: "Space", while: "deserializing from database"))
                return
            }
        } catch {
            completionHandler(PKServerError.database(while: "updating space"))
            return
        }
        
        if let markings = json["markings"].string {
            space.markings = markings
        } else if let _ = json["markings"].null {
            space.markings = ""
        }
        
        do {
            let _ = try collection.findAndUpdate("_id" == id, with: Document(space))
            completionHandler(nil)
        } catch {
            completionHandler(PKServerError.database(while: "updating space"))
        }
    }
    
    static func delete(id: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["spaces"]
        
        // TODO: If any events are on the space, server should react
        Log.warning("Feature not yet implemented, checking")
        
        do {
            let _ = try collection.findAndRemove("_id" == id)
            completionHandler(nil)
            return
        } catch {
            completionHandler(PKServerError.database(while: "deleting spaces"))
            return
        }
    }
}

public func spacesRouter() -> Router {
    let router = Router()
    
    
    return router
}

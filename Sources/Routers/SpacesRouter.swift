import Kitura
import KituraNet
import MongoKitten
import SwiftyJSON

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
        
    }
    
    static func read(id: ObjectId, completionHandler: (_ json: JSON?, _ error: PKServerError?) -> Void) {
        
    }
    
    static func update(id: ObjectId, with json: JSON, completionHandler: (_ json: JSON?, _ error: PKServerError?) -> Void) {
        
    }
    
    static func delete(id: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        
    }
}

public func spacesRouter() -> Router {
    let router = Router()
    
    
    return router
}

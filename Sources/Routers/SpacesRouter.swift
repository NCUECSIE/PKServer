import Kitura
import KituraNet
import MongoKitten
import SwiftyJSON
import LoggerAPI

import Common
import Models
import ResourceManager
import Utilities
import Middlewares

// TODO: Should agents populate fee for the space?

internal struct SpacesActions {
    static func create(latitude: Double, longitude: Double, markings: String,
                       charge: Double, unitTime: Double, providerId: ObjectId,
                       completionHandler: (_ insertedId: String?, _ error: PKServerError?) -> Void) {
        let Providers = PKResourceManager.shared.database["providers"]
        let collection = PKResourceManager.shared.database["spaces"]
        let space = PKSpace(provider: providerId, latitude: latitude, longitude: longitude, markings: markings, fee: Fee(unitTime: unitTime, charge: charge))
        
        // 檢查 Provider 是否存在
        do {
            if try Providers.findOne("_id" == providerId) == nil {
                // 沒有找到
                completionHandler(nil, PKServerError.notFound)
                return
            }
        } catch {
            completionHandler(nil, PKServerError.database(while: "checking if the provider exist"))
            return
        }
        
        do {
            let primitive = try collection.insert(Document(space))
            guard let insertedId = primitive.to(ObjectId.self) else {
                completionHandler(nil, PKServerError.deserialization(data: "ObjectId", while: "reading response from MongoKitten"))
                return
            }
            completionHandler(insertedId.hexString, nil)
        } catch {
            completionHandler(nil, PKServerError.database(while: "inserting new document"))
        }
    }
    
    static func read(in grid: NonConsecutiveGrids, completionHandler: (_ json: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["spaces"]
        
        let gridsQuery = grid.consecutiveGrids.map {
            grids in
            [
                "location.coordinates.0": [
                    "$gte": grids.lowerLeft.longitude,
                    "$lt": grids.upperRight.longitude.nextDown
                ],
                "location.coordinates.1": [
                    "$gte": grids.lowerLeft.latitude,
                    "$lt": grids.upperRight.latitude.nextDown
                ]
            ]
        }
        
        let query: Query = [
            "$or": gridsQuery
        ]
        
        print(query)
        
        do {
            var hasDeserializeError = false
            let spaces = try collection.find(query).map({ (document: Document) -> PKSpace in
                guard let space = PKSpace.deserialize(from: document) else {
                    hasDeserializeError = true
                    return PKSpace(provider: ObjectId(0)!, latitude: 0.0, longitude: 0.0, markings: "", fee: Fee(unitTime: 0, charge: 0))
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
            completionHandler(nil, .database(while: "querying documents in a collection"))
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
    
    router.post(handler: { req, res, next in
        guard let body = req.body?.asJSON,
            let providerIdString = body["providerId"].string,
            let providerId = try? ObjectId(providerIdString) else {
                throw PKServerError.missingBody(fields: [])
        }
        
        try AuthenticationMiddleware.mustBeAuthenticated(to: "create new space", as: [.agent(provider: providerId, access: .readWrite)])(req, res, next)
    }, { req, res, next in
        guard let body = req.body?.asJSON,
            let providerIdString = body["providerId"].string,
            let providerId = try? ObjectId(providerIdString),
            let longitude = body["longitude"].double,
            let latitude = body["latitude"].double,
            let markings = body["markings"].string,
            let charge = body["charge"].double,
            let unitTime = body["unitTime"].double else {
                throw PKServerError.missingBody(fields: [])
        }
        
        SpacesActions.create(latitude: latitude, longitude: longitude, markings: markings, charge: charge, unitTime: unitTime, providerId: providerId) { insertedId, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(insertedId!)
            }
        }
    })
    
    router.get(handler: { req, res, next in
        guard let gridString = req.queryParameters["grids"] else {
            throw PKServerError.notFound
        }
        
        let nonConsecutiveGrids = NonConsecutiveGrids(stringLiteral: gridString)
        if nonConsecutiveGrids.count == 0 || nonConsecutiveGrids.count > 100 {
            throw PKServerError.unauthorized(to: "get this many grids")
        }
        
        SpacesActions.read(in: nonConsecutiveGrids) { json, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: json!)
            }
        }
    })
    
    router.get(":id", handler: { req, res, next in
        guard let idString = req.parameters["id"],
            let id = try? ObjectId(idString) else {
            throw PKServerError.deserialization(data: "ObjectId", while: "reading route parameter")
        }
        
        SpacesActions.read(id: id) { json, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: json!)
            }
        }
    })
    
    router.patch(":id", handler: { req, res, next in
        guard let spaceId = try? ObjectId(req.parameters["id"]!) else {
                throw PKServerError.deserialization(data: "ObjectId", while: "reading route parameter")
        }
        
        let collection = req.database["spaces"]
        do {
            guard let space = try collection.findOne("_id" == spaceId).to(PKSpace.self) else {
                res.error = PKServerError.notFound
                next()
                return
            }
            
            let providerId = space.provider._id
            try AuthenticationMiddleware.mustBeAuthenticated(to: "update new space", as: [.agent(provider: providerId, access: .readWrite)])(req, res, next)
        } catch {
            throw PKServerError.database(while: "retrieving space data for identifying provider")
        }
    }, { req, res, next in
        guard let body = req.body?.asJSON else {
                throw PKServerError.missingBody(fields: [])
        }
        
        SpacesActions.update(id: try! ObjectId(req.parameters["id"]!), with: body) { error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send("")
            }
        }
    })
    
    router.delete(":id", handler: { req, res, next in
        guard let spaceId = try? ObjectId(req.parameters["id"]!) else {
            throw PKServerError.deserialization(data: "ObjectId", while: "reading route parameter")
        }
        
        let collection = req.database["spaces"]
        do {
            guard let space = try collection.findOne("_id" == spaceId).to(PKSpace.self) else {
                res.error = PKServerError.notFound
                next()
                return
            }
            
            let providerId = space.provider._id
            try AuthenticationMiddleware.mustBeAuthenticated(to: "delete space", as: [.agent(provider: providerId, access: .readWrite)])(req, res, next)
        } catch {
            throw PKServerError.database(while: "retrieving space data for identifying provider")
        }
    }, { req, res, next in
        SpacesActions.delete(id: try! ObjectId(req.parameters["id"]!)) { error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send("")
            }
        }
    })
    
    return router
}

import Kitura
import MongoKitten

//internal modules
import Models
import Middlewares
import Common
import ResourceManager

fileprivate struct ProviderActions {
    static func create(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) -> Void {
        let collection = request.database["providers"]
        
        //required keys: "_id", "name", "type", ""
        guard let body = request.body?.asJSON , let name = body["name"].string, let type = body["type"].string else {
            response.error = PKServerError.missingBody(fields: [])
            return
        }
        
        var exist:Document?  = nil
        let query = [
            "providers": ["$elematch":
                [
                    "name": name,
                    "type": type
                ]
            ]
        ] as Query
        
        do{
            exist = try collection.findOne(query)
        }catch {
            exist = nil
            response.error = PKServerError.database(while: "looking for duplicate provider.")
            return
        }
        if(exist == nil) {
            do {
                let provider = PKProvider(name: name, type: PKProviderType(rawValue: type)!)
                _ = try collection.insert(Document(provider)!)
            }catch {
                response.error = PKServerError.database(while: "inserting PKProvider.")
                return
            }
        } else {
            response.error = PKServerError.unknown(description: "Provider already exists.")
            next()
            return
        }
        
        
        return
    }
    
    static func read(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) -> Void {
        let collection = request.database["providers"]
        
        guard let body = request.body?.asJSON, let name = body["name"].string else {
            response.error = PKServerError.missingBody(fields: [])
            return
        }
        
        let query = [
            "$elematch": [
                "name": name
            ]
        ] as Query
        
        let projection = [
            "name": true,
            "type": true,
            "contactInformation": true
        ] as Projection
        
        var result: Document? = nil
        do {
            result = try collection.findOne(query, projecting: projection)
        }catch {
            response.error = PKServerError.database(while: "Finding provider.")
        }
        
        if(result == nil) {
            response.error = PKServerError.unknown(description: "Can't find provider")
        } else {
            let payload = Dictionary(result)
            response.send(json: payload!)
        }
        return
    }
    static func update(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) -> Void {
        let collection = request.database["providers"]
        
        guard let body = request.body?.asJSON, let name = body["name"].string, let type = body["type"].string else {
            response.error = PKServerError.missingBody(fields: [])
            return
        }
        
        let filter = [
            "$elematch": [
                "name": name
            ]
        ] as Query
        
        let update = [
            "name": name,
            "type": type
        ]
        
        var result: Document? = nil
        do {
            result = try collection.findAndUpdate(filter, with: Document(update)!)
        } catch {
            response.error = PKServerError.database(while: "Updating provider.")
        }
        
        if(result == nil) {
            response.error = PKServerError.unknown(description: "Fail to update provider.")
        } else {
            let payload = Dictionary(result)
            response.send(json: payload!)
        }
        
        return
    }
    static func delete(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) -> Void {
        let collection = request.database["providers"]
        
        guard let body = request.body?.asJSON, let name = body["name"].string, let type = body["type"].string else {
            response.error = PKServerError.missingBody(fields: [])
            return
        }

        let filter = [
            "$elematch": [
                "name": name,
                "type": type
            ]
        ] as Query
        
        var result: Document? = nil
        do {
            result = try collection.findAndRemove(filter)
        } catch {
            response.error = PKServerError.database(while: "Deleting provider.")
        }
        if(result == nil) {
            response.error = PKServerError.unknown(description: "Fail to delete provider.")
        } else {
            let payload = Dictionary(result)
            response.send(json: payload!)
        }
        
        return
    }
}

public func providersRouter() -> Router {
    let router = Router()
    
    router.post(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "adding new provider", as: [PKUserType.admin(access: .readWrite)]), ProviderActions.create)
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "read provider information", as: [PKUserType.admin(access: .readOnly)]), ProviderActions.read)
    // Admin, Agent
    router.patch(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "update provider information", as: [PKUserType.admin(access: .readWrite)]), ProviderActions.update) // Name, Contact Information
    router.delete(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "delete provider", as: [PKUserType.admin(access: .readWrite)]), ProviderActions.delete)
    
    return router
}

import Kitura
import MongoKitten

struct AuthenticationMiddleware: RouterMiddleware {
    func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        request.userInfo["user"] = Optional<PKUser>(nilLiteral: ())
        request.userInfo["authenticatedScope"] = Optional<PKTokenScope>(nilLiteral: ())
        
        guard let token = request.headers["token"] else {
            next()
            return
        }
        
        let collection = request.database["users"]
        let query = [
            "tokens": [
                "$elemMatch": [
                    "value": token
                ]
            ]
        ] as Query
        var result: Document? = nil
        do {
            result = try collection.findOne(query)
        } catch {
            throw PKServerError.database(while: "trying to fetch your user data from collection.")
        }
        
        if result != nil {
            guard let deserialized = PKUser.deserialize(from: result!) else {
                throw PKServerError.deserialization(data: "Users", while: "fetching your record from database.")
            }
            request.userInfo["user"] = Optional<PKUser>(deserialized)
            // let foundToken =
            request.userInfo["authenticatedScope"] = Optional<PKTokenScope>(deserialized.tokens.first(where: { pkToken in pkToken.value == token })!.scope)
            
            next()
        } else {
            throw PKServerError.badToken
        }
    }
    
    static func mustBeAuthenticated(for action: String, as expectedScope: PKTokenScope? = nil) -> (RouterRequest, RouterResponse, @escaping () -> Void) throws -> Void {
        return { request, response, next in
            guard let _ = request.user,
                  let scope = request.authenticatedScope else {
                throw PKServerError.requiresAuthentication(action: action)
            }
            if let expectedScope = expectedScope, scope != expectedScope {
                throw PKServerError.requiresAuthentication(action: action)
            }
            
            next()
        }
    }
}

extension RouterRequest {
    var user: PKUser? {
        return (self.userInfo["user"] as! PKUser?)
    }
    var authenticatedScope: PKTokenScope? {
        return (self.userInfo["authenticatedScope"] as! PKTokenScope?)
    }
}

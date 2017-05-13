import Kitura
import MongoKitten

// MARK: Internal Modules
import Models
import Common

public struct AuthenticationMiddleware: RouterMiddleware {
    public func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        request.userInfo["user"] = Optional<PKUser>(nilLiteral: ())
        request.userInfo["userType"] = Optional<PKUserType>(nilLiteral: ())
        
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
            
            let tokenIndex = deserialized.tokens.index(where: { pkToken in pkToken.value == token })!
            let token = deserialized.tokens[tokenIndex]
            
            switch token.scope {
            case .standard:
                request.userInfo["userType"] = Optional<PKUserType>(.standard)
            case .admin:
                let adminUserType = deserialized.types.first(where: { (type: PKUserType) -> Bool in
                    if case .admin(_) = type {
                        return true
                    }
                    return false
                })!
                request.userInfo["userType"] = Optional<PKUserType>(adminUserType)
            case .agent(provider: let providerId):
                let agentUserType = deserialized.types.first(where: { (type: PKUserType) -> Bool in
                    switch type {
                    case .agent(provider: providerId, access: _):
                        return true
                    default:
                        return false
                    }
                })!
                request.userInfo["userType"] = Optional<PKUserType>(agentUserType)
            }
            
            next()
        } else {
            throw PKServerError.badToken
        }
    }
    
    public static func mustBeAuthenticated(to action: String, as types: [PKUserType] = []) -> (RouterRequest, RouterResponse, @escaping () -> Void) throws -> Void {
        return { request, response, next in
            guard let _ = request.user else {
                throw PKServerError.unauthorized(to: action)
            }
            let requestUserType = request.userType!
            
            if types.isEmpty {
                next()
                return
            }
            
            let first = types.first(where: { (type: PKUserType) -> Bool in
                switch (type, requestUserType) {
                case (.agent(provider: let lhs, access: .readOnly), .agent(provider: let rhs, access: _)):
                    return lhs == rhs
                case (.agent(provider: let lhs, access: .readWrite), .agent(provider: let rhs, access: .readWrite)):
                    return lhs == rhs
                case (.admin(access: .readOnly), .admin(access: _)): fallthrough
                case (.admin(access: .readWrite), .admin(access: .readWrite)): fallthrough
                case (.standard, .standard):
                    return true
                default:
                    return false
                }
            })
            guard let _ = first else {
                throw PKServerError.unauthorized(to: action)
            }
            
            next()
        }
    }
    
    public init() {}
}

public extension RouterRequest {
    public var user: PKUser? {
        return (self.userInfo["user"] as! PKUser?)
    }
    public var userType: PKUserType? {
        return (self.userInfo["userType"] as! PKUserType?)
    }
}

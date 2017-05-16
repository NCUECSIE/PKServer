import Foundation
import Kitura
import KituraNet
import SwiftyJSON
import CryptoSwift
import MongoKitten

// MARK: Internal Modules
import Common
import Middlewares
import Models
import ResourceManager

protocol PKSocialLoginProviderActions {
    /**
     從要求找出使用者資訊
     - Parameter userId: 使用者的 ID（若存在）
     - Parameter accessToken: 使用者的權杖（若存在）
     - Parameter completionHandler: 找到使用者 ID 後的回呼
     - Parameter credentials: 使用者資訊
     - Parameter error: 失敗的原因
     */
    static func validate(userId: String?, accessToken: String?, completionHandler: @escaping (_ credentials: (userId: String, accessToken: String)?, _ error: PKServerError?) -> Void)
}

struct FacebookLoginProviderActions: PKSocialLoginProviderActions {
    /// 驗證使用者權杖以及取得使用者 ID
    ///
    /// - Parameters:
    ///   - accessToken: 使用者權杖
    ///   - callback: 回呼
    ///   - userId: 使用者 ID
    ///   - error: 錯誤
    static func getFacebookUserId(for accessToken: String, callback: @escaping (_ userId: String?, _ error: PKServerError?) -> Void) {
        // 1. 先確認使用者聲稱的權杖是否有效
        // 1.1 產生 appsecret_proof
        var proof: String! = nil
        do {
            let hashed = try HMAC(key: PKResourceManager.shared.config.facebookSecret, variant: .sha256).authenticate(accessToken.utf8.map({ $0 }))
            proof = Data(bytes: hashed).toHexString()
        } catch {
            callback(nil, PKServerError.crypto(while: "trying to hash your Facebook access token."))
            return
        }
        var urlComponents = URLComponents(string: "https://graph.facebook.com/me")!
        urlComponents.queryItems = [
            URLQueryItem(name: "appsecret_proof", value: proof!),
            URLQueryItem(name: "access_token", value: accessToken)
        ]
        guard let url = urlComponents.url else {
            callback(nil, PKServerError.unknown(description: "Unable to create URL to confirm your identity."))
            return
        }
        
        // 1.2 網路要求，呼叫 Facebook API
        URLSession.shared.dataTask(with: url) { data, _, error -> Void in
            guard error == nil, let data = data else {
                callback(nil, PKServerError.network(while: "confirming your identity with Facebook."))
                return
            }
            let body = JSON(data: data)
            guard let userId = body["id"].string  else {
                callback(nil, PKServerError.serialization(data: "from Facebook", while: "reading response from Facebook."))
                return
            }
            
            callback(userId, nil)
        }.resume()
    }
    static func validate(userId: String?, accessToken: String?, completionHandler: @escaping (_ credentials: (userId: String, accessToken: String)?, _ error: PKServerError?) -> Void) {
        guard let accessToken = accessToken else {
            completionHandler(nil, PKServerError.missingBody(fields: [(name: "accessToken", type: "String")]))
            return
        }
        
        getFacebookUserId(for: accessToken) { userId, error in
            switch (userId, error) {
            case (.none, .some(let err)):
                completionHandler(nil, err)
            case (.some(let validatedUserId), _):
                if let userId = userId {
                    if validatedUserId != userId {
                        completionHandler(nil, PKServerError.unknown(description: "User ID does not match Access Token."))
                        return
                    }
                }
                
                completionHandler((userId: validatedUserId, accessToken: accessToken), nil)
            default:
                completionHandler(nil, PKServerError.unknown(description: "Code path that is unreachable is reached."))
            }
        }
    }
}

/// 表示使用者想要登入取得的權限
enum LoginRequestScope: RawRepresentable {
    typealias RawValue = String
    case standard
    case agent(provider: ObjectId?)
    case admin
    
    init?(rawValue: String) {
        switch rawValue {
        case "standard": self = .standard
        case "agent": self = .agent(provider: nil)
        case "admin": self = .admin
        default: return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .standard: return "standard"
        case .agent(_): return "agent"
        case .admin: return "admin"
        }
    }
    mutating func write(provider: String) throws {
        do {
            let objectId = try ObjectId(provider)
            self.write(provider: objectId)
        } catch {
            throw PKServerError.deserialization(data: "Provider ID", while: "parsing string as ObjectID")
        }
    }
    mutating func write(provider: ObjectId) {
        switch self {
        case .agent(_):
            self = .agent(provider: provider)
        default:
            break
        }
    }
}

struct AuthActions {
    static let providerActions: [PKSocialLoginProvider: PKSocialLoginProviderActions.Type] = [
        .facebook: FacebookLoginProviderActions.self
    ]
    static func findUser(with provider: PKSocialLoginProvider, userId: String, in collection: MongoKitten.Collection) throws -> PKUser? {
        let providerRawValue = provider.rawValue
        let query = [
            "links": [ "$elemMatch":
                [
                    "provider": providerRawValue,
                    "userId": userId
                ]
            ]
            ] as Query
        
        var result: Document? = nil
        do {
            result = try collection.findOne(query)
        } catch {
            throw PKServerError.database(while: "trying to fetch your user data from collection.")
        }
        
        if result == nil { return nil }
        else {
            guard let deserialized = PKUser.deserialize(from: result!) else {
                throw PKServerError.deserialization(data: "Users", while: "fetching your record from database.")
            }
            return deserialized
        }
    }
    static func delete(user: PKUser, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void ) {
        // TODO: Check if there are reservations, parked cars, uninvoiced records, or unpaid invoices
        
        let collection = PKResourceManager.shared.database["users"]
        do {
            _ = try collection.remove("_id" == user._id!)
        } catch {
            completionHandler(nil, PKServerError.database(while: "removing user from database"))
        }
        
        completionHandler(nil, nil)
    }
    
    // MARK: 型態安全的方法
    static func inspect(user: PKUser?, type: PKUserType?, completionHandler: @escaping (_ response: JSON) -> Void) {
        var payload: [String: JSON] = [ "loggedin": JSON(user != nil) ]
        if let type = type {
            switch type {
            case .standard:
                payload["scope"] = "standard"
            case .admin(access: .readOnly):
                payload["scope"] = "admin"
                payload["access"] = "read"
            case .admin(access: .readWrite):
                payload["scope"] = "admin"
                payload["access"] = "write"
            case .agent(provider: let provider, access: .readOnly):
                payload["scope"] = "agent"
                payload["access"] = "read"
                payload["target"] = JSON(provider.hexString)
            case .agent(provider: let provider, access: .readWrite):
                payload["scope"] = "agent"
                payload["access"] = "write"
                payload["target"] = JSON(provider.hexString)
            }
            
            payload["userId"] = JSON(user!._id!.hexString)
        }
        
        completionHandler(JSON(payload))
    }
    static func registerOrLogin(strategy: PKSocialLoginProvider, userId: String?, token: String?, scope: LoginRequestScope, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void ) {
        let collection = PKResourceManager.shared.database["users"]
        let strategyActions = AuthActions.providerActions[strategy]!
        
        // 確認社群資訊
        strategyActions.validate(userId: userId, accessToken: token) { credentials, error in
            guard let (userId, accessToken) = credentials else {
                completionHandler(nil, error!)
                return
            }
            
            var user: PKUser? = nil
            var token: PKToken? = nil
            
            // 判斷登入或者是註冊
            do {
                user = try AuthActions.findUser(with: strategy, userId: userId, in: collection)
            } catch {
                completionHandler(nil, (error as! PKServerError))
                return
            }
            
            if user == nil {
                // 必須是已知的使用者，才能使用其他權限！
                if scope != .standard {
                    completionHandler(nil, PKServerError.unknown(description: "You must have proper authentication set up to be able to login as other roles."))
                    return
                }
                
                // 製造出一般使用者
                user = PKUser(initialLink: PKSocialLoginLink(provider: .facebook, userId: userId, accessToken: accessToken))
                token = user!.createNewToken(of: .standard)
            } else {
                switch scope {
                case .agent(provider: nil):
                    let providers = user!.types.reduce([JSON](), {
                        if case .agent(provider: let provider, _) = $1 {
                            var result = $0
                            result.append(JSON(stringLiteral: provider.hexString))
                            return result
                        } else {
                            return $0
                        }
                    })
                    
                    completionHandler(JSON(providers), nil)
                    return
                case .standard:
                    token = user!.createNewToken(of: .standard)
                case .agent(provider: .some(let providerId)):
                    let canAccess = user!.types.reduce(false, {
                        if case .agent(provider: let provider, _) = $1 {
                            return providerId == provider || $0
                        } else {
                            return false || $0
                        }
                    })
                    guard canAccess else {
                        completionHandler(nil, PKServerError.unauthorized(to: "access designated provider."))
                        return
                    }
                    token = user!.createNewToken(of: .agent(provider: providerId))
                case .admin:
                    let canAccess = user!.types.contains {
                        if case .admin(_) = $0 {
                            return true
                        } else {
                            return false
                        }
                    }
                    guard canAccess else {
                        completionHandler(nil, PKServerError.unauthorized(to: "access designated provider."))
                        return
                    }
                    token = user!.createNewToken(of: .admin)
                }
            }
            
            var query: Query? = nil
            if let userId = user!._id {
                query = "_id" == userId
            } else {
                query = "_id" == ObjectId()
            }
            
            do {
                _ = try collection.update(query!, to: Document(user!), upserting: true)
            } catch {
                print(error.localizedDescription)
                completionHandler(nil, PKServerError.database(while: "updating user information."))
                return
            }
            
            completionHandler(JSON(stringLiteral: token!.value), nil)
        }
    }
    static func add(link strategy: PKSocialLoginProvider, userId: String?, token: String?, to user: PKUser, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["users"]
        let strategyActions = AuthActions.providerActions[strategy]!
        
        strategyActions.validate(userId: userId, accessToken: token) { credentials, error in
            guard let (userId, accessToken) = credentials else {
                completionHandler(nil, error!)
                return
            }
            
            // Link must not exist already!
            do {
                let existing = try AuthActions.findUser(with: strategy, userId: userId, in: collection)
                if existing != nil {
                    completionHandler(nil, .linkExisted)
                    return
                }
            } catch {
                completionHandler(nil, .database(while: "checking for redundant social account"))
                return
            }
            
            var user = user
            user.links.append(PKSocialLoginLink(provider: strategy, userId: userId, accessToken: accessToken))
            
            do {
                _ = try collection.findAndUpdate("_id" == user._id!, with: Document(user))
            } catch {
                completionHandler(nil, .database(while: "updating user information."))
                return
            }
            
            completionHandler("", nil)
        }
    }
    static func remove(link strategy: PKSocialLoginProvider, userId: String, from user: PKUser, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["users"]
        var user = user
        
        user.links = user.links.filter { $0.provider != strategy || $0.userId != userId }
        
        if user.links.isEmpty {
            completionHandler(nil, .cannotRemoveLastLink)
            return
        }
        
        do {
            _ = try collection.findAndUpdate("_id" == user._id!, with: Document(user))
        } catch {
            completionHandler(nil, PKServerError.database(while: "updating user information."))
            return
        }
        
        completionHandler("", nil)
    }
    static func links(user: PKUser, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void) {
        let payload = user.links.map { JSON([ "provider": JSON($0.provider.rawValue), "userId": JSON($0.userId) ]) }
        completionHandler(JSON(payload), nil)
    }
}

/**
 取得認證的路由：
 
 - 登入（`login`）相關路徑
 
   *不必註冊即可登入*
 
   + 使用 Facebook（`POST login/facebook`）
 
     必須在主體中帶有 `scope` 以及 `accessToken` 兩個鍵
 
 - 帳號（`account`）
   - 登入方法（`links`）
     + 查看（`GET accounts`）
     + 新增 Facebook（`POST account/links/facebook`）
 
       必須在主體中帶有 `scope` 以及 `accessToken` 兩個鍵
 
     - 刪除 Facebook（`DELETE account/links/facebook/:facebookUserId`)
   - 刪除帳號（`DELETE account`）
 
 */
public func authRouter() -> Router {
    let router = Router()
    
    /// 解析資訊，傳給 AuthActions 的 registerOrLogin 靜態方法
    router.post("login/:strategy", handler: { request, response, next in
        guard let strategyString = request.parameters["strategy"],
            let strategy = PKSocialLoginProvider(rawValue: strategyString),
            let body = request.body?.asJSON,
            let scopeString = body["scope"].string,
            var scope = LoginRequestScope(rawValue: scopeString) else {
                response.status(HTTPStatusCode.notFound).send("Strategy is not known.")
                return
        }
        
        if case .agent(_) = scope {
            if let providerId = body["provider"].string {
                try scope.write(provider: providerId)
            }
        }
        
        let userId = body["userId"].string
        let accessToken = body["accessToken"].string
        
        // 用型態安全的方法
        AuthActions.registerOrLogin(strategy: strategy, userId: userId, token: accessToken, scope: scope) { json, error in
            guard let json = json else {
                response.error = error
                next()
                return
            }
            
            if let token = json.string {
                // 字串不能直接傳送
                response.send(token)
            } else {
                // 陣列可以
                response.send(json: json)
            }
        }
    })
    
    router.delete("account", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "remove your own account."), { request, response, next in
        let user = request.user!
        AuthActions.delete(user: user) { _, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            _ = response.send(status: .OK)
        }
    })
    router.all("account/links", allowPartialMatch: true, middleware: linksRouter())
    
    /// 解析資訊，傳給 AuthActions 的 inspect 靜態方法
    router.get(handler: { request, response, next in
        AuthActions.inspect(user: request.user, type: request.userType) { json in
            response.send(json: json)
        }
    })
    return router
}

fileprivate func linksRouter() -> Router {
    let router = Router()
    
    /// 回傳連結
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "check all social links"), { request, response, next in
        let user = request.user!
        AuthActions.links(user: user) { json, error in
            response.send(json: json!)
        }
    })
    
    /// 新增連結
    router.post(":strategy", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "add social link"), { request, response, next in
        guard let strategyString = request.parameters["strategy"],
            let strategy = PKSocialLoginProvider(rawValue: strategyString),
            let body = request.body?.asJSON else {
                response.status(HTTPStatusCode.notFound).send("Strategy is not known.")
                return
        }
        let userId = body["userId"].string
        let accessToken = body["accessToken"].string
        
        AuthActions.add(link: strategy, userId: userId, token: accessToken, to: request.user!) { _, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            _ = response.send(status: .OK)
        }
    })
    
    /// 刪除連結
    router.delete(":strategy/:socialId", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "remove social account"), { request, response, next in
        guard let strategyString = request.parameters["strategy"],
            let strategy = PKSocialLoginProvider(rawValue: strategyString),
            let socialId = request.parameters["socialId"] else {
                response.status(HTTPStatusCode.notFound).send("Strategy is not known.")
                return
        }
        
        AuthActions.remove(link: strategy, userId: socialId, from: request.user!) { _, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            _ = response.send(status: .OK)
        }
    })
    
    return router
}

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
    static func findUser(with strategy: PKSocialStrategy, userId: String, in collection: MongoKitten.Collection) throws -> PKUser? {
        let providerRawValue = strategy.rawValue
        let query = [
            "strategies": [ "$elemMatch":
                [
                    "strategy": providerRawValue,
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
    static func registerOrLogin(strategy: PKSocialStrategy, userId: String?, token: String?, scope: LoginRequestScope, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void ) {
        let collection = PKResourceManager.shared.database["users"]
        
        // 確認社群資訊
        strategy.validate(userId: userId, accessToken: token) { credentials, error in
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
                user = PKUser(initialStrategy: PKSocialLoginStrategy(strategy: .facebook, userId: userId, accessToken: accessToken))
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
}

///
/// 提供使用者註冊、登入以及管理登入策略的功能
/// 
/// # 路徑
///
/// - 註冊、登入 `POST *strategy`
///
/// # 策略（strategy）
/// 1. Facebook
///
///    必須提供 JSON 主體以及 JSON 鍵 `accessToken`
///
public func authRouter() -> Router {
    let router = Router()
    
    /// 解析資訊，傳給 AuthActions 的 registerOrLogin 靜態方法
    router.post(":strategy", handler: { request, response, next in
        guard let strategyString = request.parameters["strategy"],
            let strategy = PKSocialStrategy(rawValue: strategyString),
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
    
    return router
}

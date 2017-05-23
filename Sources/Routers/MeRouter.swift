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

struct MeActions {
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
    static func add(strategy: PKSocialStrategy, userId: String?, token: String?, to user: PKUser, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["users"]
        
        strategy.validate(userId: userId, accessToken: token) { credentials, error in
            guard let (userId, accessToken) = credentials else {
                completionHandler(nil, error!)
                return
            }
            
            // Strategy must not exist already!
            do {
                let existing = try AuthActions.findUser(with: strategy, userId: userId, in: collection)
                if existing != nil {
                    completionHandler(nil, .strategyExisted)
                    return
                }
            } catch {
                completionHandler(nil, .database(while: "checking for redundant social account"))
                return
            }
            
            var user = user
            user.strategies.append(PKSocialLoginStrategy(strategy: strategy, userId: userId, accessToken: accessToken))
            
            do {
                _ = try collection.findAndUpdate("_id" == user._id!, with: Document(user))
            } catch {
                completionHandler(nil, .database(while: "updating user information."))
                return
            }
            
            completionHandler("", nil)
        }
    }
    static func remove(strategy: PKSocialStrategy, userId: String, from user: PKUser, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["users"]
        var user = user
        
        user.strategies = user.strategies.filter { $0.strategy != strategy || $0.userId != userId }
        
        if user.strategies.isEmpty {
            completionHandler(nil, .cannotRemoveLastStrategy)
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
    static func strategies(user: PKUser, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void) {
        let payload = user.strategies.map { JSON([ "provider": JSON($0.strategy.rawValue), "userId": JSON($0.userId) ]) }
        completionHandler(JSON(payload), nil)
    }
}

///
/// 提供使用者帳號、登入策略以及車輛管理等功能
///
/// # 路徑
/// - 權杖檢視   `GET /`
/// - 刪除帳號   `DELETE /`
/// - 策略管理   `GET strategies`
/// - 新增策略   `POST strategies/*strategy`
/// - 刪除策略   `DELETE strategies/facebook/*userId`
/// - 檢視車輛   `GET vehicles`
/// - 增加車輛   `POST vehicles`
///
/// # 策略（strategy）
/// 1. Facebook
///
///    必須提供 JSON 主體以及 JSON 鍵 `accessToken`
///
/// # 車輛（vehicle）
/// 必須提供 JSON 主體以及 `vehicleId` 鍵，其值為 16 字長的字串
///
public func meRouter() -> Router {
    let router = Router()
    
    router.get(handler: { request, response, next in
        MeActions.inspect(user: request.user, type: request.userType) { json in
            response.send(json: json)
        }
    })
    router.delete(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "remove your own account."), { request, response, next in
        let user = request.user!
        MeActions.delete(user: user) { _, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            _ = response.send(status: .OK)
        }
    })
    router.all("strategies", allowPartialMatch: true, middleware: strategiesRouter())
    router.all("vehicles", allowPartialMatch: true, middleware: vehiclesRouter())
    
    return router
}

fileprivate func strategiesRouter() -> Router {
    let router = Router()
    
    /// 回傳連結
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "check all social strategies"), { request, response, next in
        let user = request.user!
        MeActions.strategies(user: user) { json, error in
            response.send(json: json!)
        }
    })
    
    /// 新增連結
    router.post(":strategy", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "add social strategy"), { request, response, next in
        guard let strategyString = request.parameters["strategy"],
            let strategy = PKSocialStrategy(rawValue: strategyString),
            let body = request.body?.asJSON else {
                response.status(HTTPStatusCode.notFound).send("Strategy is not known.")
                return
        }
        let userId = body["userId"].string
        let accessToken = body["accessToken"].string
        
        MeActions.add(strategy: strategy, userId: userId, token: accessToken, to: request.user!) { _, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            _ = response.send(status: .OK)
        }
    })
    
    /// 刪除連結
    router.delete(":strategy/:socialId", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "remove social strategy"), { request, response, next in
        guard let strategyString = request.parameters["strategy"],
            let strategy = PKSocialStrategy(rawValue: strategyString),
            let socialId = request.parameters["socialId"] else {
                response.status(HTTPStatusCode.notFound).send("Strategy is not known.")
                return
        }
        
        MeActions.remove(strategy: strategy, userId: socialId, from: request.user!) { _, error in
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

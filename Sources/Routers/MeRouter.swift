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
    static func makeAdmin(user: PKUser, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void ) {
        let collection = PKResourceManager.shared.database["users"]
        var u = user
        
        var isAdmin = false
        for (i, type) in u.types.enumerated() {
            if case .admin(access: .readOnly) = type {
                u.types[i] = .admin(access: .readWrite)
                isAdmin = true
                break
            } else if case .admin(access: .readWrite) = type {
                isAdmin = true
                break
            }
        }
        
        if !isAdmin {
            u.types.append(.admin(access: .readWrite))
        }
        
        do {
            let id = user._id!
            let query = "_id" == id
            _ = try collection.update(query, to: Document(u), upserting: false, multiple: false)
        } catch {
            completionHandler(nil, .database(while: "updating user information."))
            return
        }
        
        completionHandler(nil, nil)
    }
    static func makeAgent(user: PKUser, forProvider providerId: ObjectId, completionHandler: @escaping (_ response: JSON?, _ error: PKServerError?) -> Void ) {
        let collection = PKResourceManager.shared.database["users"]
        var u = user
        
        let providersColletion = PKResourceManager.shared.database["providers"]
        do {
            let result = try providersColletion.findOne("_id" == providerId)
            if result == nil {
                completionHandler(nil, PKServerError.notFound)
                return
            }
            
            var isAgent = false
            for (i, type) in u.types.enumerated() {
                if case .agent(provider: providerId, access: .readOnly) = type {
                    u.types[i] = .agent(provider: providerId, access: .readWrite)
                    isAgent = true
                    break
                } else if case .agent(provider: providerId, access: .readWrite) = type {
                    isAgent = true
                    break
                }
            }
            if !isAgent {
                u.types.append(PKUserType.agent(provider: providerId, access: .readWrite))
            }
            
            let id = user._id!
            let query = "_id" == id
            _ = try collection.update(query, to: Document(u), upserting: false, multiple: false)
        } catch {
            completionHandler(nil, .database(while: "updating user information."))
            return
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
    
    router.get("", handler: { request, response, next in
        MeActions.inspect(user: request.user, type: request.userType) { json in
            response.send(json: json)
        }
    })
    router.delete("", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "remove your own account."), { request, response, next in
        let user = request.user!
        MeActions.delete(user: user) { _, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            response.send("")
        }
    })
    router.post("make_admin", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "make yourself admin."), { request, response, next in
        let user = request.user!
        MeActions.makeAdmin(user: user) { _, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            response.send("")
        }
    })
    router.post("make_agent", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "make yourself agent."), { req, response, next in
        guard let body = req.body?.asJSON,
            let idString = body["providerId"].string,
            let id = try? ObjectId(idString) else {
            throw PKServerError.missingBody(fields: [])
        }
        
        let user = req.user!
        MeActions.makeAgent(user: user, forProvider: id) { _, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            response.send("")
        }
    })
    
    router.all("strategies", allowPartialMatch: true, middleware: strategiesRouter())
    router.all("vehicles", allowPartialMatch: true, middleware: vehiclesRouter())
    router.all("devices", allowPartialMatch: true, middleware: devicesRouter())
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

// MARK: 車輛異動

internal struct VehiclesActions {
    /// 取得所有車輛 ID
    ///
    /// - Parameters:
    ///   - user: 使用者
    ///   - completionHandler: 回呼
    ///   - result: 使用者車輛 ID
    ///   - error: 錯誤
    ///
    /// 此方法保證 `result != nil` 以及 `error == nil`
    ///
    static func read(in user: PKUser, completionHandler: (_ result: JSON?, _ error: PKServerError?) -> Void) {
        completionHandler(JSON(user.vehicles.map { $0.json }), nil)
    }
    
    static func create(plate: String, tag: String, in user: PKUser, completionHandler: (_ error: PKServerError?) -> Void) {
        let query: Query = [
            "vehicles": [ "$elemMatch": [ "tag": tag ] ]
        ]
        do {
            let result = try PKResourceManager.shared.database["users"].findOne(query)
            if (result != nil) {
                completionHandler(.unknown(description: "vehicle already exists"))
                return
            }
        } catch {
            completionHandler(.database(while: "checking for duplicate vehicleId"))
            return
        }
        
        do {
            var u = user
            u.vehicles.append(PKVehicle(tag: tag, plate: plate))
            _ = try PKResourceManager.shared.database["users"].findAndUpdate("_id" == u._id!, with: Document(u))
            completionHandler(nil)
        } catch {
            completionHandler(.database(while: "updating database"))
        }
    }
}

/// 提供使用者管理旗下車輛 ID 的功能
///
/// # 路徑
///
/// - 取得列表 `GET  /`
/// - 新增車輛 `POST /`
///
///   必須為 JSON 主體，並有 `vehicleId` 鍵
///
public func vehiclesRouter() -> Router {
    let router = Router()
    
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "retrieve vehicles list", as: [PKUserType.standard]), { req, res, next in
        VehiclesActions.read(in: req.user!) { result, error in
            res.send(json: result!)
        }
    })
    
    router.post(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "retrieve vehicles list", as: [PKUserType.standard]), { req, res, next in
        guard let body = req.body?.asJSON,
            let plate = body["plate"].string,
            let tag = body["tag"].string else {
                throw PKServerError.missingBody(fields: [])
        }
        
        VehiclesActions.create(plate: plate, tag: tag, in: req.user!) { error in
            if let err = error {
                res.error = err
                next()
            } else {
                res.send("")
            }
        }
    })
    
    return router
}

internal struct DevicesActions {
    static func create(device: String, in user: PKUser, completionHandler: (_ result: Result<Void>) -> Void) {
        do {
            var u = user
            u.deviceIds.append(device)
            _ = try PKResourceManager.shared.database["users"].findAndUpdate("_id" == u._id!, with: Document(u))
            completionHandler(.success())
        } catch {
            completionHandler(.error(.database(while: "updating database")))
        }
    }
}
public func devicesRouter() -> Router {
    let router = Router()
    
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "retrieve vehicles list", as: [PKUserType.standard]), { req, res, next in
        guard let body = req.body?.asJSON,
            let device = body["deviceId"].string else {
                throw PKServerError.deserialization(data: "String", while: "reading deviceId")
        }
        
        DevicesActions.create(device: device, in: req.user!) { result in
            switch result {
            case .success(_):
                res.send("")
            case .error(let err):
                res.error = err
                next()
            }
        }
    })
    
    return router
}

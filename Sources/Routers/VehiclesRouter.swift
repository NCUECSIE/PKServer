import Foundation
import Kitura
import MongoKitten
import SwiftyJSON

// Internal Modules
import Models
import Middlewares
import Common
import ResourceManager

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
        completionHandler(JSON(user.vehicleIds.map { JSON($0) }), nil)
    }
    
    static func create(vehicle id: String, in user: PKUser, completionHandler: (_ error: PKServerError?) -> Void) {
        do {
            var u = user
            u.vehicleIds.append(id)
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
    
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "retrieve vehicles list", as: [PKUserType.standard]), { req, res, next in
        guard let body = req.body?.asJSON,
            let id = body["vehicleId"].string,
            id.utf8.count == 16 else {
                throw PKServerError.missingBody(fields: [ (name: "vehicleId", type: "String[16]") ])
        }
        
        VehiclesActions.create(vehicle: id, in: req.user!) { error in
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

import Foundation
import Kitura
import MongoKitten
import SwiftyJSON
import LoggerAPI

// Internal Modules
import Models
import Middlewares
import Common
import ResourceManager
import Utilities

struct ParkingActions {
    static func read(of user: PKUser, completionHandler: (_ result: Result<JSON>) -> Void) {
        do {
            let parkings = try PKResourceManager.shared.database["parking"].find("user.$id" == user._id!).flatMap { $0.to(PKParking.self) }
            completionHandler(.success(JSON(parkings.map {$0.detailedJSON})))
        } catch {
            completionHandler(.error(PKServerError.database(while: "")))
        }
    }
}

public func parkingRouter() -> Router {
    let router = Router()
    
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "read currently parked", as: [.standard]), { req, res, next in
        ParkingActions.read(of: req.user!) { result in
            switch result {
            case .success(let parking):
                res.send(json: parking)
            case .error(let error):
                res.error = error
                next()
            }
        }
    })
    
    return router
}

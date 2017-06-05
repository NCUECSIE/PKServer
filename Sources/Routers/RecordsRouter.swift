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

struct RecordsActions {
    static func read(of user: PKUser, completionHandler: (Result<JSON>) -> Void ) {
        do {
            let records = try PKResourceManager.shared.database["records"].find("user.$id" == user._id!, sortedBy: [ "begin": .descending ]).flatMap { $0.to(PKRecord.self) }
            completionHandler(.success(JSON(records.map {$0.detailedJSON})))
        } catch {
            completionHandler(.error(PKServerError.database(while: "")))
        }
    }
}

public func recordsRouter() -> Router {
    let router = Router()
    
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "read currently parked", as: [.standard]), { req, res, next in
        RecordsActions.read(of: req.user!) { result in
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


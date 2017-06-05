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

struct ReservationsActions {
    static func read(of user: PKUser, completionHandler: (_ reservations: Result<JSON>) -> Void) {
        do {
            let reservations = try PKResourceManager.shared.database["reservations"]
                                    .find("user.$id" == user._id!)
                                    .flatMap { $0.to(PKReservation.self)?.detailedJSON }
                                    .filter { _ in true }
            completionHandler(.success(JSON(reservations)))
        } catch {
            completionHandler(.error(PKServerError.database(while: "")))
        }
    }
    static func create(for user: PKUser, when time: Date, in grid: Grid, completionHandler: (_ reservedId: Result<String>) -> Void) {
        let spacesCollection = PKResourceManager.shared.database["spaces"]
        
        let query: Query = [
            "location.coordinates.0": [
                "$gte": grid.consecutiveGrids[0].lowerLeft.longitude,
                "$lt": grid.consecutiveGrids[0].upperRight.longitude.nextDown
            ],
            "location.coordinates.1": [
                "$gte": grid.consecutiveGrids[0].lowerLeft.latitude,
                "$lt": grid.consecutiveGrids[0].upperRight.latitude.nextDown
            ],
            "deleted": false
        ]
        
        do {
            let documents = try spacesCollection.find(query)
            let spacesIds = try documents.flatMap { $0.to(PKSpace.self)?._id }.filter { _ in true }
            
            let parkingCollection = PKResourceManager.shared.database["parking"]
            let reservationsCollection = PKResourceManager.shared.database["reservations"]
            
            let parked = try parkingCollection
                .find([ "space.$id": [ "$in": spacesIds ] ])
                .flatMap { $0.to(PKParking.self)?.space._id }
                .filter { _ in true }
            let reserved = try reservationsCollection
                .find([ "space.$id": [ "$in": spacesIds ] ])
                .flatMap { $0.to(PKReservation.self)?.space._id }
                .filter { _ in true }
            let occupied = parked + reserved
            
            let free = spacesIds.filter { !occupied.contains($0) }
            
            if free.isEmpty { // 沒有可以出租的
                completionHandler(.error(PKServerError.unknown(description: "No empty spaces for reservation")))
            } else { // 出租
                // print(free[0])
                NotificationCenter.default.post(name: PKNotificationType.spaceReserved.rawValue, object: nil, userInfo: ["spaceId": free[0], "grid": grid.description])
                try reservationsCollection.insert(Document(PKReservation(spaceId: free[0], userId: user._id!, begin: time)))
                completionHandler(.success(free[0].hexString))
            }
        } catch {
            completionHandler(.error(PKServerError.database(while: "")))
        }
    }
    static func delete(for user: PKUser, id: ObjectId, completionHandler: (_ result: Result<Void>) -> Void) {
        do {
            guard let reservation = try PKResourceManager.shared.database["reservations"].find("_id" == id).filter({_ in true})[0].to(PKReservation.self),
            let space = reservation.space.fetch().0 else {
                completionHandler(.error(PKServerError.deserialization(data: "PKReservation", while: "reporting space unoccupied")))
                return
            }
            let grid = Grid(containing: space.location.latitude, space.location.longitude).description
            NotificationCenter.default.post(name: PKNotificationType.spaceFreed.rawValue, object: nil, userInfo: ["spaceId": space._id!, "grid": grid.description, "cancelledReservation": true])
            
            _ = try PKResourceManager.shared.database["reservations"].remove("_id" == id)
            completionHandler(.success())
        } catch {
            completionHandler(.error(PKServerError.database(while: "")))
        }
    }
}

public func reservationsRouter() -> Router {
    let router = Router()
    
    router.get("", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "list reservations", as: [.standard]), { req, res, next in
        ReservationsActions.read(of: req.user!) { result in
            switch result {
            case .success(let reservations):
                res.send(json: reservations)
            case .error(let error):
                res.error = error
                next()
            }
        }
    })
    router.post("", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "reserve space in grid", as: [.standard]), { req, res, next in
        let dateFormatter = ISO8601DateFormatter()
        
        guard let body = req.body?.asJSON,
            let timeString = body["time"].string,
            let time = dateFormatter.date(from: timeString),
            let gridString = body["grid"].string,
            let grid = Grid(string: gridString),
            time > Date() else {
                throw PKServerError.missingBody(fields: [])
        }
        
        
        ReservationsActions.create(for: req.user!, when: time, in: grid) { result in
            switch result {
            case .success(let id):
                res.send(id)
            case .error(let error):
                res.error = error
                next()
            }
        }
    })
    router.delete(":id", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "reserve space in grid", as: [.standard]), { req, res, next in
        guard let id = try? ObjectId(req.parameters["id"]!) else {
            throw PKServerError.deserialization(data: "ObjectId", while: "parsing URI")
        }
        guard let reservation = try PKResourceManager.shared.database["reservations"].findOne("_id" == id).to(PKReservation.self) else {
            throw PKServerError.database(while: "checking that the reservation belongs to you")
        }
        if reservation.user._id != req.user!._id! {
            throw PKServerError.unauthorized(to: "delete someone else's reservation")
        }
        
        ReservationsActions.delete(for: req.user!, id: id) { result in
            switch result {
            case .success(_):
                res.send("")
            case .error(let error):
                res.error = error
                next()
            }
        }
    })
    
    return router
}

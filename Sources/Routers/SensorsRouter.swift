import Foundation
import Kitura
import MongoKitten
import SwiftyJSON
import LoggerAPI

// Internal Modules
import Utilities
import Models
import Middlewares
import Common
import ResourceManager

struct SensorsActions {
    static func didStartParking(tag: String, on sensorId: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        // 找出車輛歸屬者！
        let query: Query = [
            "vehicles": [ "$elemMatch" : [ "tag": tag ] ]
        ]
        
        do {
            guard let document = try PKResourceManager.shared.database["users"].findOne(query) else {
                completionHandler(.notFound)
                return
            }
            guard let user = PKUser.deserialize(from: document) else {
                completionHandler(PKServerError.deserialization(data: "User", while: "checking belonging user of vehicle"))
                return
            }
            
            let userId = user._id!
            guard let spaceId = try PKResourceManager.shared.database["sensors"].findOne("_id" == sensorId).to(PKSensor.self)?.space._id else {
                Log.error("space does not exist")
                return
            }
            
            guard let space = try PKResourceManager.shared.database["spaces"].findOne("_id" == spaceId).to(PKSpace.self) else {
                completionHandler(.database(while: "findone failed"))
                return
            }
            
            if let _ = try PKResourceManager.shared.database["parking"].findOne("space.$id" == spaceId).to(PKParking.self) {
                didStopParking(on: sensorId, completionHandler: { _ in })
            }
            
            let plate = user.vehicles.first { $0.tag == tag }!.plate
            try PKResourceManager.shared.database["parking"].insert(Document(PKParking(spaceId: spaceId, userId: userId, plate: plate, begin: Date())))
            
            NotificationCenter.default.post(name: PKNotificationType.spaceParked.rawValue, object: nil, userInfo: ["spaceId": spaceId, "grid": Grid(containing: space.location.latitude, space.location.longitude).description])
            completionHandler(nil)
            
            // 處理特殊狀況
            if var reservation = try PKResourceManager.shared.database["reservations"].findOne("space.$id" == spaceId).to(PKReservation.self) {
                let grid = Grid(containing: space.location.latitude, space.location.longitude)
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
                
                // 1. 此車位已經被預約了！
                if reservation.user._id == userId {
                    // 1.1 預約屬於同一個人的！
                    _ = try PKResourceManager.shared.database["reservations"].findAndRemove("_id" == reservation._id!)
                } else {
                    // 1.2 預約屬於不同人的 QQ
                    // 1.2.1 改預約位置
                    
                    let spacesCollection = PKResourceManager.shared.database["spaces"]
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
                    
                    guard let user = reservation.user.fetch().0 else {
                        Log.error("Cannot cancel existing user reservation to make room for existing parking")
                        return
                    }
                    
                    if free.isEmpty {
                        // 在霸佔者中產生 10 元罰金
                        // 在被霸佔者中產生 -10 元補償
                        
                        // 沒有可以出租的，通知預約被取消
                        NotificationCenter.default.post(name: PKNotificationType.userReservationCancelled.rawValue, object: nil, userInfo: [
                            "user": user,
                            "reservation": reservation
                        ])
                        // 刪除預約
                        _ = try PKResourceManager.shared.database["reservations"].findAndRemove("space.$id" == spaceId)
                    } else {
                        let newlyAppointed = free[0]
                        // 通知出租（主要是要通知 Sensor 以及 Redis）
                        NotificationCenter.default.post(name: PKNotificationType.spaceReserved.rawValue, object: nil, userInfo: ["spaceId": newlyAppointed, "grid": grid.description])
                        // 修改預約
                        reservation.space = PKDbRef(id: newlyAppointed, collectionName: "spaces")
                        // 通知預約被改
                        NotificationCenter.default.post(name: PKNotificationType.userReservationChanged.rawValue, object: nil, userInfo: [
                            "user": user,
                            "reservation": reservation
                        ])
                        // 寫回資料庫
                        _ = try PKResourceManager.shared.database["reservations"].findAndUpdate("_id" == reservation._id!, with: Document(reservation))
                    }
                }
            }
        } catch {
            completionHandler(.database(while: "retrieving belonging user of the vehicle"))
        }
    }
    static func didStopParking(on sensorId: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        do {
            let space = (try PKResourceManager.shared.database["sensors"].findOne("_id" == sensorId).to(PKSensor.self)?.space.fetch().0)!
            let spaceId = space._id!
            NotificationCenter.default.post(name: PKNotificationType.spaceFreed.rawValue, object: nil, userInfo: ["spaceId": spaceId, "grid": Grid(containing: space.location.latitude, space.location.longitude).description])
            
            guard let parking = try PKResourceManager.shared.database["parking"].findOne("space.$id" == spaceId).to(PKParking.self) else {
                completionHandler(PKServerError.database(while: "find one specific space.id during stop parking"))
                return
            }
            
            let end = Date()
            
            let charge = end.timeIntervalSince(parking.begin)
            let spanCount = Int(ceil(charge / space.fee.unitTime))
            
            try PKResourceManager.shared.database["parking"].remove("_id" == parking._id!)
            let record = PKRecord(spaceId: spaceId, userId: parking.user._id, plate: parking.plate!, begin: parking.begin, end: end, charge: Double(spanCount) * space.fee.charge)
            
            try PKResourceManager.shared.database["records"].insert(Document(record))
            
            completionHandler(nil)
        } catch {
            completionHandler(.database(while: ""))
        }
    }
    
    static func create(address: Data, space: ObjectId, completionHandler: (_ secret: String?, _ error: PKServerError?) -> Void) {
        // check if space is already occupied?
        do {
            let stringAddress: String = String(physicalAddress: address) ?? ""
            guard try PKResourceManager.shared.database["sensors"].findOne("space.$id" == space) == nil else {
                completionHandler(nil, PKServerError.unknown(description: "a sensor is already set to report status of the specified space"))
                return
            }
            
            //add by sugarPeter886
            guard try PKResourceManager.shared.database["sensors"].findOne("address" == stringAddress) == nil else {
                completionHandler(nil, PKServerError.database(while: "looking for duplicate physical address"))
                return
            }
        } catch {
            completionHandler(nil, PKServerError.database(while: "checking existing sensor for duplicate space"))
            return
        }
        
        let sensor = PKSensor(address: address, spaceId: space)
        do {
            _ = try PKResourceManager.shared.database["sensors"].insert(Document(sensor))
            completionHandler(sensor.secret, nil)
        } catch {
            completionHandler(nil, PKServerError.database(while: "inserting sensor"))
            return
        }
    }
    static func readNetworks(completionHandler: (_ result: JSON?, _ error: PKServerError?) -> Void) {
        do {
            guard let distinctNetworks = try PKResourceManager.shared.database["sensors"].distinct(on: "networkId") else {
                completionHandler(nil, PKServerError.database(while: "got nil while unwrapping MongoKitten result"))
                return
            }
            let result = distinctNetworks.flatMap({ $0.to(Int.self)})
            let json = JSON(result)
            
            completionHandler(json, nil)
        } catch {
            completionHandler(nil, PKServerError.database(while: "reading distinct network values"))
            return
        }
    }
    static func read(completionHandler: (_ result: JSON?, _ error: PKServerError?) -> Void) {
        do {
            let documents = try PKResourceManager.shared.database["sensors"].find()
            let sensors = documents.map({ document -> PKSensor in
                print(document)
                return PKSensor.deserialize(from: document)!
            })
            let jsons = sensors.map { $0.simpleJSON }
            completionHandler(JSON(jsons), nil)
        } catch {
            completionHandler(nil, PKServerError.database(while: "retrieving sensor"))
        }
    }
    static func read(id: ObjectId, completionHandler: (_ result: JSON?, _ error: PKServerError?) -> Void) {
        do {
            guard let document = try PKResourceManager.shared.database["sensors"].findOne("_id" == id) else {
                completionHandler(nil, .notFound)
                return
            }
            guard let sensor = document.to(PKSensor.self) else {
                completionHandler(nil, PKServerError.deserialization(data: "sensor", while: "retrieving sensor"))
                return
            }
            completionHandler(sensor.detailedJSON, nil)
        } catch {
            completionHandler(nil, PKServerError.database(while: "retrieving sensor"))
        }
    }
    static func read(in networkId: Int, completionHandler: (_ result: JSON?, _ error: PKServerError?) -> Void) {
        do {
            let documents = try PKResourceManager.shared.database["sensors"].find("networkId" == networkId)
            let sensors = documents.flatMap({ $0.to(PKSensor.self) })
            let jsons = sensors.map { $0.detailedJSON }
            completionHandler(JSON(jsons), nil)
        } catch {
            completionHandler(nil, PKServerError.database(while: "retrieving sensor"))
        }
    }
    static func delete(id: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        do {
            try PKResourceManager.shared.database["sensors"].remove("_id" == id)
            completionHandler(nil)
        } catch {
            completionHandler(PKServerError.database(while: "deleting sensor"))
        }
    }
}

public func sensorsRouter() -> Router {
    let router = Router()
    
    /// Authorizes a request based on JSON body, 
    /// Checks `physicalAddress` and `secret` fields
    /// - Postcondition:
    ///   The sensor id (of type `ObjectId`) is available in `userInfo["sensorId"]`
    func authorizeSensor(_ req: RouterRequest, _ res: RouterResponse, _ next: () -> Void) throws {
        guard let body = req.body?.asJSON,
            let addressString = body["physicalAddress"].string,
            let address = Data(physicalAddress: addressString),
            let secret = body["secret"].string else {
                throw PKServerError.missingBody(fields: [ (name: "physicalAddress", type: "String") ])
        }
        
        var fetched: Document?
        do {
            fetched = try PKResourceManager.shared.database["sensors"].findOne("address" == address)
        } catch {
            throw PKServerError.database(while: "fetching sensor with the specified physical address.")
        }
        
        guard let document = fetched else {
            throw PKServerError.notFound
        }
        
        guard let sensor = PKSensor.deserialize(from: document) else {
            throw PKServerError.deserialization(data: "Sensor", while: "authorizing")
        }
        
        if sensor.secret == secret {
            req.userInfo["sensorId"] = sensor._id!
            next()
        } else {
            throw PKServerError.unauthorized(to: "perform sensor updates")
        }
    }
    
    // Payload: 
    // {
    //   "physicalAddress": "aa:aa:aa:aa:aa:aa",
    //   "parked": true
    //   "vehicleId": "acc90d83d47880cf"
    // }
    // or
    // {
    //   "physicalAddress": "aa:aa:aa:aa:aa:aa",
    //   "parked": false
    // }
    //
    router.post("updates", handler: authorizeSensor, { req, res, next in
        let sensorId = req.userInfo["sensorId"] as! ObjectId
        let body = req.body!.asJSON!
        guard let parked = body["parked"].bool else {
            throw PKServerError.missingBody(fields: [(name: "parked", type: "Bool")])
        }
        
        if parked {
            guard let tag = body["tag"].string else {
                throw PKServerError.missingBody(fields: [(name: "tag", type: "String")])
            }
            
            SensorsActions.didStartParking(tag: tag, on: sensorId) { err in
                if let error = err {
                    res.error = error
                    next()
                } else {
                    res.send("")
                }
            }
        } else {
            SensorsActions.didStopParking(on: sensorId) { err in
                if let error = err {
                    res.error = error
                    next()
                } else {
                    res.send("")
                }
            }
        }
    })
    
    router.post("", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "create new sensor", as: [.admin(access: .readWrite)]), { req, res, next in
        guard let body = req.body?.asJSON,
            let addressString = body["physicalAddress"].string,
            let address = Data(physicalAddress: addressString),
            let spaceIdString = body["spaceId"].string,
            let spaceId = try? ObjectId(spaceIdString) else {
                throw PKServerError.missingBody(fields: [])
        }
        
        SensorsActions.create(address: address, space: spaceId) { secret, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(secret!)
            }
        }
    })
    
    router.get("", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "list sensors", as: [.admin(access: .readOnly)]), { req, res, next in
        SensorsActions.read() { result, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: result!)
            }
        }
    })
    
    router.get(":id", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "read a sensor", as: [.admin(access: .readOnly)]), { req, res, next in
        let idString = req.parameters["id"]!
        guard let id = try? ObjectId(idString) else {
            throw PKServerError.deserialization(data: "ObjectId", while: "parsing URI")
        }
        
        SensorsActions.read(id: id) { result, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: result!)
            }
        }
    })
    
    router.delete(":id", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "delete a sensor", as: [.admin(access: .readWrite)]), { req, res, next in
        let idString = req.parameters["id"]!
        guard let id = try? ObjectId(idString) else {
            throw PKServerError.deserialization(data: "ObjectId", while: "parsing URI")
        }
        
        SensorsActions.delete(id: id) { error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send("")
            }
        }
    })
    
    return router
}

public func networksRouter() -> Router {
    let router = Router()
    
    router.get(handler: { req, res, next in
        SensorsActions.readNetworks() { result, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: result!)
            }
        }
    })
    
    router.get(":networkId", handler: { req, res, next in
        let networkIdString = req.parameters["networkId"]!
        guard let networkId = Int(networkIdString) else {
            throw PKServerError.deserialization(data: "Int", while: "parsing networkId in URI")
        }
        SensorsActions.read(in: networkId) { result, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: result!)
            }
        }
    })
    
    return router
}

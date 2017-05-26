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

// Supports:
// - (admin ro) Read sensor
// - (admin ro) Read sensor under specified network
// - (admin rw) Deleting sensor

struct SensorsActions {
    static func didStartParking(vehicleId: String, on sensorId: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        // 找出車輛歸屬者！
        let query: Query = [
            "vehicleIds": [ "$elemMatch" : vehicleId ]
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
            
            // TODO: Post notification
            // TODO: Create "parking"
            Log.error("Unimplemented: Fare counting")
            
            completionHandler(nil)
        } catch {
            completionHandler(.database(while: "retrieving belonging user of the vehicle"))
        }
    }
    static func didStopParking(on sensorId: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        // TODO: Post notification
        // TODO: Turn "parking" into "record"
        Log.error("Unimplemented: Fare counting")
    }
    
    static func create(address: Data, space: ObjectId, completionHandler: (_ secret: String?, _ error: PKServerError?) -> Void) {
        // check if space is already occupied?
        do {
            guard let _ = try PKResourceManager.shared.database["sensors"].findOne("space.$id" == space) else {
                completionHandler(nil, PKServerError.unknown(description: "a sensor is already set to report status of the specified space"))
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
            guard let documents = try PKResourceManager.shared.database["sensors"].find("networkId" == networkId) else {
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
    static func delete(id: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        
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
            fetched = try PKResourceManager.shared.database["sensors"].findOne("physicalAddress" == address)
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
            guard let vehicleId = body["vehicleId"].string else {
                throw PKServerError.missingBody(fields: [(name: "vehicleId", type: "String")])
            }
            
            SensorsActions.didStartParking(vehicleId: vehicleId, on: sensorId) { err in
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
    
    return router
}

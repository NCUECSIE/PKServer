import Foundation
import LoggerAPI
import KituraWebSocket
import SwiftyJSON
import MongoKitten
import ResourceManager
import PKAutoSerialization
import Models
import Common

internal class SensorActions {
    static func update(physicalAddress: Data, networkId nId: Int, metricDistance mDistance: Int, routes: [(destination: Data, through: Data)])  {
        do {
            guard let document = try PKResourceManager.shared.database["sensors"].findOne("address" == physicalAddress) else {
                throw PKServerError.notFound
            }
            guard var sensor = PKSensor.deserialize(from: document) else {
                throw PKServerError.deserialization(data: "Sensor", while: "reading document from database")
            }
            
            sensor.networkId = nId
            sensor.metricDistance = mDistance
            sensor.routes = routes.map { Route(destination: $0.destination, through: $0.through)! }
            sensor.updated = Date()
            
            let updatedDocument = Document(sensor)
            try PKResourceManager.shared.database["sensors"].update("address" == physicalAddress, to: updatedDocument)
        } catch let error where error is PKServerError {
            Log.error((error as! PKServerError).localizedDescription)
        } catch let error where error is MongoError {
            Log.error("MongoError while updating sensor information" + (error as! MongoError).debugDescription)
        } catch {
            Log.error("Unknown error while updating sensor information")
        }
    }
}

public class SensorService: WebSocketService {
    public static var shared: SensorService!
    private var connections: [String: WebSocketConnection]
    private var recognizedConnections: [String: WebSocketConnection]
    
    public func connected(connection: WebSocketConnection) {
        connections[connection.id] = connection
        Log.info("Sensor connected via WebSocket")
    }
    
    public func disconnected(connection: WebSocketConnection, reason: WebSocketCloseReasonCode) {
        connections.removeValue(forKey: connection.id)
        Log.info("Sensor disconnected from WebSocket")
    }
    
    public func received(message: Data, from connection: WebSocketConnection) {
        SensorService.lastReceived = .Binary(message, Date())
        Log.warning("Received binary data from sensor: \(message) \(message.map({$0}).description)")
        Log.warning("Will disconnect sensor")
        
        connection.close(reason: .invalidDataType, description: "This service only receives JSON string.")
    }
    
    public func notifyReservation(sensorAddress: Data) {
        let address = String(physicalAddress: sensorAddress)!
        let payload: JSON = [
            "destination": address,
            "type": "reservation"
        ]
        recognizedConnections[address]?.send(message: payload.rawString()!)
    }
    public func notifyCancelledReservation(sensorAddress: Data) {
        let address = String(physicalAddress: sensorAddress)!
        let payload: JSON = [
            "destination": address,
            "type": "cancelledReservation"
        ]
        recognizedConnections[address]?.send(message: payload.rawString()!)
    }
    
    public func received(message: String, from connection: WebSocketConnection) {
        let json = JSON.parse(string: message)
        if json.null == nil {
            SensorService.lastReceived = .JSON(json, Date())
            
            guard let networkId = json["networkId"].int,
                let metricDistance = json["metricDistance"].int,
                let physicalAddressString = json["physicalAddress"].string,
                let physicalAddress = Data(physicalAddress: physicalAddressString),
                let routesJSON = json["routes"].array else {
                    Log.warning("Received bad JSON data from sensor: \(message)")
                    Log.warning("Will disconnect sensor")
                    
                    connection.close(reason: .invalidDataType, description: "JSON data missing fields")
                    return
            }
            let routes = routesJSON.flatMap { element -> (destination: Data, through: Data)? in
                let result = (destination: Data(physicalAddress: element["destination"].stringValue), through: Data(physicalAddress: element["through"].stringValue))
                if result.destination == nil || result.through == nil {
                    return nil
                } else {
                    return (destination: result.destination!, through: result.through!)
                }
            }
            
            if routes.count != routesJSON.count {
                Log.warning("Received bad JSON data from sensor: \(message)")
                Log.warning("Will disconnect sensor")
                
                connection.close(reason: .invalidDataType, description: "JSON data missing in routes array")
                return
            }
            
            recognizedConnections[physicalAddressString] = connection
            SensorActions.update(physicalAddress: physicalAddress, networkId: networkId, metricDistance: metricDistance, routes: routes)
        } else {
            SensorService.lastReceived = .String(message, Date())
            Log.warning("Received string data from sensor: \(message)")
            Log.warning("Will disconnect sensor")
            
            connection.close(reason: .invalidDataType, description: "This service only receives JSON string.")
            connections.removeValue(forKey: connection.id)
        }
    }
    
    public init() {
        connections = [:]
        recognizedConnections = [:]
        SensorService.shared = self
        
        NotificationCenter.default.addObserver(forName: PKNotificationType.spaceReserved.rawValue, object: nil, queue: nil) { [unowned self] notification in
            let userInfo = notification.userInfo!
            let spaceId = userInfo["spaceId"] as! ObjectId
            let sensorAddress = try! PKResourceManager.shared.database["sensors"].findOne("space.$id" == spaceId).to(PKSensor.self)?.address
            
            self.notifyReservation(sensorAddress: sensorAddress!)
        }
        NotificationCenter.default.addObserver(forName: PKNotificationType.spaceFreed.rawValue, object: nil, queue: nil) { [unowned self] notification in
            let userInfo = notification.userInfo!
            let spaceId = userInfo["spaceId"] as! ObjectId
            let sensorAddress = try! PKResourceManager.shared.database["sensors"].findOne("space.$id" == spaceId).to(PKSensor.self)?.address
            
            if let _ = userInfo["cancelledReservation"] {
                self.notifyCancelledReservation(sensorAddress: sensorAddress!)
            }
        }
    }
    
    // MARK: 為了支援 Debug 功能
    public enum ReceivedData {
        case String(String, Date)
        case Binary(Data, Date)
        case JSON(JSON, Date)
    }
    public static var lastReceived: ReceivedData?
}

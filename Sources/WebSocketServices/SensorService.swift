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
    static func update(sensor id: ObjectId, networkId nId: Int, metricDistance mDistance: Int, routes: [(destination: Data, through: Data)])  {
        do {
            guard let document = try PKResourceManager.shared.database["sensors"].findOne("_id" == id) else {
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
            try PKResourceManager.shared.database["sensors"].update("_id" == id, to: updatedDocument)
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
    private var connections: [String: WebSocketConnection]
    
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
    
    public func received(message: String, from connection: WebSocketConnection) {
        let json = JSON.parse(string: message)
        if json.null == nil {
            SensorService.lastReceived = .JSON(json, Date())
            
            guard let networkId = json["networkId"].int,
                let metricDistance = json["metricDistance"].int,
                let sensorIdStringValue = json["sensorId"].string,
                let sensorId = try? ObjectId(sensorIdStringValue),
                let physicalAddressString = json["physicalAddress"].string,
                let _ = Data(physicalAddress: physicalAddressString),
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
            
            SensorActions.update(sensor: sensorId, networkId: networkId, metricDistance: metricDistance, routes: routes)
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
    }
    
    // MARK: 為了支援 Debug 功能
    public enum ReceivedData {
        case String(String, Date)
        case Binary(Data, Date)
        case JSON(JSON, Date)
    }
    public static var lastReceived: ReceivedData?
}

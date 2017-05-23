import Foundation
import LoggerAPI
import KituraWebSocket

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
    
    public func received(message: Data, from: WebSocketConnection) {
        Log.debug("Received from sensor: \(message) \(message.map({$0}).description)")
    }
    
    public func received(message: String, from connection: WebSocketConnection) {
        connection.close(reason: WebSocketCloseReasonCode.invalidDataType, description: "Sensor service only accepts binary messages.")
        Log.warning("Sensor sent a string message, will disconnect.")
    }
    
    public init() {
        connections = [:]
    }
}

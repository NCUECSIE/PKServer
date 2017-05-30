import Foundation
import LoggerAPI
import KituraWebSocket
import SwiftyJSON
import MongoKitten
import ResourceManager
import PKAutoSerialization
import Models
import Utilities
import Common


public class AppService: WebSocketService {
    private var connections: [String: WebSocketConnection]
    private var subscribed: [String: [WebSocketConnection]]
    
    public func connected(connection: WebSocketConnection) {
        connections[connection.id] = connection
        Log.info("Application connected via WebSocket")
    }
    
    public func disconnected(connection: WebSocketConnection, reason: WebSocketCloseReasonCode) {
        connections.removeValue(forKey: connection.id)
        Log.info("Application disconnected from WebSocket")
    }
    
    public func received(message: Data, from connection: WebSocketConnection) {
        let messageType = message.bytes[0]
        guard let gridString = String(bytes: message.bytes.dropFirst(), encoding: .utf8) else { return }
        let components = gridString.components(separatedBy: ":")
        
        guard components.count == 2,
            let latitude = Double(components[0]),
            let longitude = Double(components[1]) else {
                return
        }
        
        let grid = Grid(containing: latitude, longitude)
        let spec = grid.description
        
        switch messageType {
        case 0:
            if let index = subscribed[spec]?.index(where: { $0 === connection }) {
                subscribed[spec]!.remove(at: index)
            }
        case 1:
            if subscribed[spec] == nil {
                subscribed[spec] = []
            }
            
            subscribed[spec]!.append(connection)
        default:
            break
        }
    }
    
    public func received(message: String, from connection: WebSocketConnection) {}
    
    private enum AppNotificationType {
        case occupied
        case unoccupied
    }
    private func notify(_ type: AppNotificationType) -> (Notification) -> Void {
        return { [unowned self] notification in
            let userInfo = notification.userInfo!
            let spaceId = userInfo["spaceId"] as! ObjectId
            let grid = userInfo["grid"] as! String
            
            self.subscribed[grid]?.forEach { connection in
                var data = Data()
                data.append(contentsOf: spaceId.bytes)
                switch type {
                case .occupied:
                    data.append(1)
                case .unoccupied:
                    data.append(0)
                }
                
                connection.send(message: data)
            }
        }
    }
    
    public init() {
        connections = [:]
        subscribed = [:]
        
        NotificationCenter.default.addObserver(forName: PKNotificationType.spaceReserved.rawValue, object: nil, queue: nil, using: notify(.occupied))
        NotificationCenter.default.addObserver(forName: PKNotificationType.spaceParked.rawValue, object: nil, queue: nil, using: notify(.occupied))
        NotificationCenter.default.addObserver(forName: PKNotificationType.spaceFreed.rawValue, object: nil, queue: nil, using: notify(.unoccupied))
    }
}

extension WebSocketService {
    public func received(message: String, from connection: WebSocketConnection) { }
}

extension ObjectId {
    var bytes: [UInt8] {
        return [
            storage.0,
            storage.1,
            storage.2,
            storage.3,
            storage.4,
            storage.5,
            storage.6,
            storage.7,
            storage.8,
            storage.9,
            storage.10,
            storage.11
        ]
    }
}

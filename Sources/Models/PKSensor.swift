import Foundation
import MongoKitten
import SwiftyJSON

import Common
import ResourceManager
import PKAutoSerialization

public struct Route: PKObjectReflectionSerializable {
    public let destination: Data
    public let through: Data
    
    public init?(destination d: Data, through t: Data) {
        if d.count != 6 || t.count != 6 {
            return nil
        }
        
        destination = d
        through = t
    }
    
    /// 路由
    public static func deserialize(from primitive: Primitive) -> Route? {
        guard let document = primitive.toDocument(requiredKeys: ["destination", "through"]),
              let destination = document["destination"].to(Data.self),
              let through = document["throguh"].to(Data.self) else {
            return nil
        }
        
        return Route(destination: destination, through: through)
    }
}

public struct PKSensor: PKModel {
    public var simpleJSON: JSON {
        return [
            "physicalAddress": String(physicalAddress: address) ?? "",
            "spaceId": space._id.hexString,
            "networkId": networkId ?? -1,
            "updated": updated ?? Date.distantFuture,
            "distance": metricDistance ?? -1
        ]
    }
    public var detailedJSON: JSON {
        return [
            "physicalAddress": String(physicalAddress: address) ?? "",
            "spaceId": space._id.hexString,
            "networkId": networkId ?? -1,
            "updated": updated ?? Date.distantFuture,
            "distance": metricDistance ?? -1,
            "routes": (routes ?? []).map { (route: Route) -> [String: String] in [
                "destination": String(physicalAddress: route.destination) ?? "",
                "through": String(physicalAddress: route.through) ?? "",
            ] }
        ]
    }
    
    /// 唯一識別碼
    public let _id: ObjectId?
    
    /// MAC 位址
    public let address: Data
    
    /// 秘密
    public let secret: String
    
    /// 相關的車位
    public let space: PKDbRef<PKSpace>
    
    /// 上一次聯絡的日期
    public var updated: Date?
    
    /// 網路 ID
    public var networkId: Int?
    
    /// 路由表
    public var routes: [Route]?
    
    /// 與 Gateway 的距離
    public var metricDistance: Int?
    
    public init(address a: Data, spaceId s: ObjectId) {
        address = a
        space = PKDbRef<PKSpace>(id: s, collectionName: "spaces")
        
        _id = nil
        updated = nil
        networkId = nil
        routes = nil
        metricDistance = nil
        
        // Creates a random hex string
        secret = randomBytes(length: 8).toHexString()
    }
    private init(_id i: ObjectId, address a: Data, secret se: String, space s: PKDbRef<PKSpace>, updated u: Date?, networkId n: Int?, routes r: [Route]?,
                 metricDistance m: Int?) {
        _id = i
        address = a
        space = s
        updated = u
        networkId = n
        routes = r
        metricDistance = m
        secret = se
    }
    
    public static func deserialize(from primitive: Primitive) -> PKSensor? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "address", "secret", "space", "updated", "networkId", "routes", "metricDistance"]),
              let i = document["_id"].to(ObjectId.self),
              let a = document["address"].to(Data.self),
              let se = document["secret"].to(String.self),
              let s = document["space"].to(PKDbRef<PKSpace>.self),
              let u = Optional<Date>.deserialize(from: document["updated"]!),
              let n = Optional<Int>.deserialize(from: document["networkId"]!),
              let m = Optional<Int>.deserialize(from: document["metricDistance"]!) else {
                return nil
        }
        
        // Optional of arrays are Primitive, and does not go through our system
        var r: [Route]? = nil
        if document["routes"]! is [Primitive] {
            let routingPrimitive = document["routes"]! as! [Primitive]
            r = try? routingPrimitive.map { primitive in
                if let result = Route.deserialize(from: primitive) {
                    return result
                } else {
                    throw PKServerError.unknown(description: "")
                }
            }
            if r == nil { return nil }
        } else if document["routes"]! is Null {
            r = nil
        } else {
            return nil
        }
        
        return PKSensor(_id: i, address: a, secret: se, space: s, updated: u, networkId: n, routes: r, metricDistance: m)
    }
}

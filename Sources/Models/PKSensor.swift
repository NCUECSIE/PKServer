import Foundation
import MongoKitten
import SwiftyJSON

import Common
import ResourceManager
import PKAutoSerialization

public struct Route: PKObjectReflectionSerializable {
    public let destination: Data
    public let through: Data
    public let hops: Int
    
    public init?(destination d: Data, through t: Data, hops h: Int) {
        if d.count != 6 || t.count != 6 {
            return nil
        }
        
        destination = d
        through = t
        hops = h
    }
    
    /// 路由
    public static func deserialize(from primitive: Primitive) -> Route? {
        guard let document = primitive.toDocument(requiredKeys: ["destination", "through", "hops"]),
              let destination = document["destination"].to(Data.self),
              let through = document["throguh"].to(Data.self),
              let hops = document["hops"].to(Int.self) else {
            return nil
        }
        
        return Route(destination: destination, through: through, hops: hops)
    }
}

public struct PKSensor: PKModel {
    public var simpleJSON: JSON {
        return [:]
    }
    public var detailedJSON: JSON {
        return [:]
    }
    
    /// 唯一識別碼
    public let _id: ObjectId?
    
    /// MAC 位址
    public let address: Data
    
    /// 相關的車位
    public let space: PKDbRef<PKSpace>
    
    /// 上一次聯絡的日期
    public let updated: Date?
    
    /// 網路 ID
    public let networkId: Int?
    
    /// 路由表
    public let routing: [Route]?
    
    /// 與 Gateway 的距離
    public let metricDistance: Int?
    
    /// 與 Gateway 的 Hop
    public let hops: Int?
    
    public init(address a: Data, spaceId s: ObjectId) {
        address = a
        space = PKDbRef<PKSpace>(id: s, collectionName: "spaces")
        
        _id = nil
        updated = nil
        networkId = nil
        routing = nil
        metricDistance = nil
        hops = nil
    }
    private init(_id i: ObjectId, address a: Data, space s: PKDbRef<PKSpace>, updated u: Date?, networkId n: Int?, routing r: [Route]?,
                 metricDistance m: Int?, hops h: Int?) {
        _id = i
        address = a
        space = s
        updated = u
        networkId = n
        routing = r
        metricDistance = m
        hops = h
    }
    
    public static func deserialize(from primitive: Primitive) -> PKSensor? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "address", "space", "updated", "networkId", "routing", "metricDistance", "hops"]),
              let i = document["_id"].to(ObjectId.self),
              let a = document["address"].to(Data.self),
              let s = document["space"].to(PKDbRef<PKSpace>.self),
              let u = Optional<Date>.deserialize(from: document["updated"]!),
              let n = Optional<Int>.deserialize(from: document["networkId"]!),
              let m = Optional<Int>.deserialize(from: document["metricDistance"]!),
              let h = Optional<Int>.deserialize(from: document["hops"]!) else {
                return nil
        }
        
        // Optional of arrays are Primitive, and does not go through our system
        var r: [Route]? = nil
        if document["routing"]! is [Primitive] {
            let routingPrimitive = document["routing"]! as! [Primitive]
            r = try? routingPrimitive.map { primitive in
                if let result = Route.deserialize(from: primitive) {
                    return result
                } else {
                    throw PKServerError.unknown(description: "")
                }
            }
            if r == nil { return nil }
        } else if document["routing"]! is Null {
            r = nil
        } else {
            return nil
        }
        
        return PKSensor(_id: i, address: a, space: s, updated: u, networkId: n, routing: r, metricDistance: m, hops: h)
    }
}

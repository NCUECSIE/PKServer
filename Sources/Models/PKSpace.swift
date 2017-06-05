import PKAutoSerialization
import CoreLocation
import Dispatch
import BSON
import SwiftyJSON
import ResourceManager
import LoggerAPI

public struct Fee: PKObjectReflectionSerializable {
    public var unitTime: TimeInterval
    public var charge: Double
    
    public init(unitTime ut: TimeInterval, charge c: Double) {
        unitTime = ut
        charge = c
    }
    public static func deserialize(from primitive: Primitive) -> Fee? {
        guard let document = primitive.toDocument(requiredKeys: ["unitTime", "charge"]),
              let s = document["unitTime"].to(Double.self),
              let c = document["charge"].to(Double.self) else {
            return nil
        }
        return Fee(unitTime: s, charge: c)
    }
}

public struct PKSpace: PKModel {
    public var simpleJSON: JSON {
        return [
            "_id": _id!.hexString,
            "location": [ "longitude": location.longitude,
                          "latitude": location.latitude ],
            "parked": parked
        ]
    }
    public var detailedJSON: JSON {
        let fetchedProvider = provider.fetch().0
        
        return JSON([
            "_id": JSON(_id!.hexString),
            "provider": fetchedProvider == nil ? JSON(nilLiteral: ()) : fetchedProvider!.simpleJSON,
            "location": [ "longitude": location.longitude,
                          "latitude": location.latitude ] as JSON,
            "markings": JSON(markings),
            "fee": [ "charge": fee.charge,
                     "unitTime": fee.unitTime ] as JSON,
            "parked": JSON(parked)
        ] as [String: JSON])
    }

    private var parked: Bool {
        let group = DispatchGroup()
        group.enter()
        
        var p = false
        PKResourceManager.shared.redis.get(_id!.hexString) { result, _ in
            if let result = result {
                if result.asString == "true" { p = true }
            }
            group.leave()
        }
        
        // Wait for .1 sec at most!
        let r = group.wait(timeout: DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 100000000))
        if case .timedOut = r {
            Log.error("DispatchGroup timed out while waiting for response.")
        }
        
        print("Redis got \(p) for \(_id!.hexString)")
        
        return p
    }
    
    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    public let provider: PKDbRef<PKProvider>
    public let location: CLLocationCoordinate2D
    public var markings: String
    public var fee: Fee
    
    public var deleted: Bool
    
    /// 從資料庫初始化
    private init(id: ObjectId, provider p: PKDbRef<PKProvider>, location l: CLLocationCoordinate2D, markings m: String,
                 fee f: Fee, deleted d: Bool) {
        _id = id
        provider = p
        location = l
        markings = m
        fee = f
        deleted = d
    }
    /// 從程式碼初始化
    public init(provider p: ObjectId, latitude: CLLocationDegrees, longitude: CLLocationDegrees, markings m: String, fee f: Fee) {
        _id = nil
        provider = PKDbRef<PKProvider>(id: p, collectionName: "providers")
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        markings = m
        fee = f
        deleted = false
    }
    
    public func serialize() throws -> Primitive {
        return [ "provider": try provider.serialize(),
                 "location": try location.serialize(),
                 "markings": markings,
                 "fee": try fee.serialize(),
                 "deleted": deleted ] as Document
    }
    public static func deserialize(from primitive: Primitive) -> PKSpace? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "provider", "location", "markings", "fee"]),
              let i = document["_id"].to(ObjectId.self),
              let p = document["provider"]!.to(PKDbRef<PKProvider>.self),
              let l = document["location"]!.to(CLLocationCoordinate2D.self),
              let m = document["markings"].to(String.self),
              let f = document["fee"]!.to(Fee.self),
              let d = document["deleted"].to(Bool.self) else {
            return nil
        }
        
        return PKSpace(id: i, provider: p, location: l, markings: m, fee: f, deleted: d)
    }
}

extension CLLocationCoordinate2D: PKPrimitiveConvertible {
    public func serialize() throws -> Primitive {
        return [ "type": "Point", "coordinates": [ longitude, latitude ] ] as Document
    }
    public static func deserialize(from primitive: Primitive) -> CLLocationCoordinate2D? {
        guard let document = primitive.toDocument(requiredKeys: ["type", "coordinates"]),
              let coordinates = document["coordinates"]!.toArray(typed: Double.self, count: 2),
              document["type"].to(String.self) == "Point" else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
    }
    
    public func convert<DT>(to type: DT.Type) -> DT.SupportedValue? where DT : DataType {
        return nil
    }
}

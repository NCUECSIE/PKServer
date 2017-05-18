import PKAutoSerialization
import CoreLocation
import BSON
import SwiftyJSON

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
                          "latitude": location.latitude ]
        ]
    }
    public var detailedJSON: JSON {
        return [
            "_id": _id!.hexString,
            "providerId": provider._id.hexString,
            "location": [ "longitude": location.longitude,
                          "latitude": location.latitude ],
            "markings": markings,
            "fee": [ "charge": fee.charge,
                     "unitTime": fee.unitTime ]
        ]
    }

    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    public let provider: PKDbRef<PKProvider>
    public let location: CLLocationCoordinate2D
    public var markings: String
    public var fee: Fee
    
    /// 從資料庫初始化
    private init(id: ObjectId, provider p: PKDbRef<PKProvider>, location l: CLLocationCoordinate2D, markings m: String,
         fee f: Fee) {
        _id = id
        provider = p
        location = l
        markings = m
        fee = f
    }
    /// 從程式碼初始化
    public init(provider p: ObjectId, latitude: CLLocationDegrees, longitude: CLLocationDegrees, markings m: String, fee f: Fee) {
        _id = nil
        provider = PKDbRef<PKProvider>(id: p, collectionName: "providers")
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        markings = m
        fee = f
    }
    
    public func serialize() throws -> Primitive {
        return [ "provider": try provider.serialize(),
                 "location": try location.serialize(),
                 "markings": markings,
                 "fee": try fee.serialize() ] as Document
    }
    public static func deserialize(from primitive: Primitive) -> PKSpace? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "provider", "location", "markings", "fee"]),
              let i = document["_id"].to(ObjectId.self),
              let p = document["provider"]!.to(PKDbRef<PKProvider>.self),
              let l = document["location"]!.to(CLLocationCoordinate2D.self),
              let m = document["markings"].to(String.self),
              let f = document["fee"]!.to(Fee.self) else {
            return nil
        }
        
        return PKSpace(id: i, provider: p, location: l, markings: m, fee: f)
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

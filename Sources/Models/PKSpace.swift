import PKAutoSerialization
import CoreLocation
import BSON

struct Fee: PKObjectReflectionSerializable {
    var span: TimeInterval
    var charge: Double
    
    static func deserialize(from primitive: Primitive) -> Fee? {
        guard let document = primitive.toDocument(requiredKeys: ["span, charge"]),
              let s = document["span"].to(Double.self),
              let c = document["charge"].to(Double.self) else {
            return nil
        }
        return Fee(span: s, charge: c)
    }
}

struct PKSpace: PKModel {
    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    public var provider: PKDbRef<PKProvider>
    public let location: CLLocationCoordinate2D
    public let markings: String
    public var fee: Fee
    
    /// 從資料庫初始化
    init(id: ObjectId, provider p: PKDbRef<PKProvider>, location l: CLLocationCoordinate2D, markings m: String,
         fee f: Fee) {
        _id = id
        provider = p
        location = l
        markings = m
        fee = f
    }
    /// 從程式碼初始化
    init(provider p: ObjectId, latitude: CLLocationDegrees, longitude: CLLocationDegrees, markings m: String, fee f: Fee) {
        _id = nil
        provider = PKDbRef<PKProvider>(id: p, collectionName: "providers")
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        markings = m
        fee = f
    }
    
    func serialize() throws -> Primitive {
        return [ "provider": try provider.serialize(),
                 "location": try location.serialize(),
                 "markings": markings,
                 "fee": try fee.serialize() ] as Document
    }
    static func deserialize(from primitive: Primitive) -> PKSpace? {
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

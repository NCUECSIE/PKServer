import BSON
import PKAutoSerialization

public enum PKProviderType: String, PKEnumReflectionSerializable {
    case government = "government"
    case `private` = "private"
}

public struct PKContactInformation: PKObjectReflectionSerializable {
    var phone: String?
    var email: String?
    var address: String?
    
    public static func deserialize(from primitive: Primitive) -> PKContactInformation? {
        guard let document = primitive.toDocument(requiredKeys: ["phone", "email", "address"]),
              let p = document["phone"].to(String?.self),
              let e = document["email"].to(String?.self),
              let a = document["address"].to(String?.self) else {
                return nil
        }
        return PKContactInformation(phone: p, email: e, address: a)
    }
}

public struct PKProvider: PKModel {
    /// 唯一識別碼
    public let _id: ObjectId?
    
    public var name: String
    public var type: PKProviderType
    public var contactInformation: PKContactInformation
    
    public init(name n: String, type t: PKProviderType) {
        _id = nil
        name = n
        type = t
        contactInformation = PKContactInformation(phone: nil, email: nil, address: nil)
    }
    private init(_id i: ObjectId, name n: String, type t: PKProviderType, contactInformation c: PKContactInformation) {
        _id = i
        name = n
        type = t
        contactInformation = c
    }
    
    public static func deserialize(from primitive: Primitive) -> PKProvider? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "name", "type", "contactInformation"]),
              let i = document["_id"]!.to(ObjectId.self),
              let n = document["name"]!.to(String.self),
              let t = document["type"]!.to(PKProviderType.self),
              let c = document["contactInformation"].to(PKContactInformation.self) else {
            return nil
        }
        return PKProvider(_id: i, name: n, type: t, contactInformation: c)
    }
}

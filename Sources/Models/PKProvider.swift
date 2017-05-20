import BSON
import SwiftyJSON
import PKAutoSerialization

public enum PKProviderType: String, PKEnumReflectionSerializable {
    case government = "government"
    case `private` = "private"
}

public struct PKContactInformation: PKObjectReflectionSerializable {
    public var phone: String?
    public var email: String?
    public var address: String?
    
    public static func deserialize(from primitive: Primitive) -> PKContactInformation? {
        guard let document = primitive.toDocument(requiredKeys: ["phone", "email", "address"]),
              let p = Optional<String>.deserialize(from: document["phone"]!),
              let e = Optional<String>.deserialize(from: document["email"]!),
              let a = Optional<String>.deserialize(from: document["address"]!) else {
                return nil
        }
        
        return PKContactInformation(phone: p, email: e, address: a)
    }
}

public struct PKProvider: PKModel {
    public var simpleJSON: JSON {
        return [
            "_id": _id!.hexString,
            "type": type.rawValue,
            "name": name
        ]
    }
    public var detailedJSON: JSON {
        return [
            "_id": _id!.hexString,
            "type": type.rawValue,
            "name": name,
            "contactInformation": [
                "phone": contactInformation.phone,
                "email": contactInformation.email,
                "address": contactInformation.address
            ]
        ]
    }
    
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

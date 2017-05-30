import Foundation
import Security
import MongoKitten
import SwiftyJSON
import BSON
import Common
import PKAutoSerialization

public struct PKRecord: PKModel {
    public var detailedJSON: JSON {
        return [
            "_id": _id!.hexString,
            "space": space.fetch().0 ?? Null(),
            "plate": plate,
            "begin": begin,
            "end": end,
            "charge": charge,
            "paid": paid
        ]
    }
    
    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    public let space: PKDbRef<PKSpace>
    let user: PKDbRef<PKUser>
    let plate: String
    
    let begin: Date
    var end: Date
    
    var charge: Double
    var paid: Bool
    
    public init(spaceId: ObjectId, userId: ObjectId, plate p: String, begin b: Date, end e: Date, charge c: Double) {
        _id = nil
        space = PKDbRef(id: spaceId, collectionName: "spaces")
        user = PKDbRef(id: userId, collectionName: "users")
        plate = p
        begin = b
        end = e
        charge = c
        paid = false
    }
    
    private init(id: ObjectId, space s: PKDbRef<PKSpace>, user u: PKDbRef<PKUser>, plate p: String, begin b: Date, end e: Date, charge c: Double, paid pa: Bool) {
        _id = id
        space = s
        user = u
        plate = p
        begin = b
        end = e
        charge = c
        paid = pa
    }
    
    public static func deserialize(from primitive: Primitive) -> PKRecord? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "space", "user", "plate", "begin", "end", "charge", "paid"]),
            let id = document["_id"].to(ObjectId.self),
            let space = document["space"].to(PKDbRef<PKSpace>.self),
            let user = document["user"].to(PKDbRef<PKUser>.self),
            let plate = document["plate"].to(String.self),
            let begin = document["begin"].to(Date.self),
            let end = document["end"].to(Date.self),
            let charge = document["charge"].to(Double.self),
            let paid = document["paid"].to(Bool.self) else {
            return nil
        }
        
        return PKRecord(id: id, space: space, user: user, plate: plate, begin: begin, end: end, charge: charge, paid: paid)
    }
}

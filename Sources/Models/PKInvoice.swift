import Foundation
import Security
import MongoKitten
import SwiftyJSON
import BSON
import Common
import PKAutoSerialization

public struct PKInvoice: PKModel {
    public var detailedJSON: JSON {
        return [
            "_id": _id?.hexString ?? "",
            "records": records.map({ $0.fetch().0! }),
            "paid": paid
        ]
    }
    
    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    let user: PKDbRef<PKUser>
    let records: [PKDbRef<PKRecord>]
    let paid: Bool
    
    public init(userId: ObjectId, recordIds: [ObjectId]) {
        _id = nil
        user = PKDbRef(id: userId, collectionName: "users")
        records = recordIds.map({ PKDbRef(id: $0, collectionName: "records") })
        paid = false
    }
    
    private init(id: ObjectId, user u: PKDbRef<PKUser>, records r: [PKDbRef<PKRecord>], paid p: Bool) {
        _id = id
        user = u
        records = r
        paid = p
    }
    
    public static func deserialize(from primitive: Primitive) -> PKInvoice? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "user", "records", "paid"]),
            let id = document["_id"].to(ObjectId.self),
            let user = document["user"].to(PKDbRef<PKUser>.self),
            let records = document["records"].toArray(typed: PKDbRef<PKRecord>.self),
            let paid = document["paid"].to(Bool.self) else {
                return nil
        }
        
        return PKInvoice(id: id, user: user, records: records, paid: paid)
    }
}

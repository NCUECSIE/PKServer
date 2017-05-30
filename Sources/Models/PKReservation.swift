import Foundation
import Security
import MongoKitten
import SwiftyJSON
import BSON
import Common
import PKAutoSerialization

public struct PKReservation: PKModel {
    public var detailedJSON: JSON {
        return [
            "_id": _id!.hexString,
            "space": space.fetch().0?.simpleJSON ?? [:],
            "begin": begin
        ]
    }
    
    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    public let space: PKDbRef<PKSpace>
    public let user: PKDbRef<PKUser>
    
    public let begin: Date
    
    private init(id: ObjectId, space s: PKDbRef<PKSpace>, user u: PKDbRef<PKUser>, begin b: Date) {
        _id = id
        space = s
        user = u
        begin = b
    }
    
    public init(spaceId: ObjectId, userId: ObjectId, begin b: Date) {
        _id = nil
        
        space = PKDbRef(id: spaceId, collectionName: "spaces")
        user = PKDbRef(id: userId, collectionName: "users")
        begin = b
    }
    
    public static func deserialize(from primitive: Primitive) -> PKReservation? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "space", "user", "begin"]),
            let id = document["_id"].to(ObjectId.self),
            let space = document["space"].to(PKDbRef<PKSpace>.self),
            let user = document["user"].to(PKDbRef<PKUser>.self),
            let begin = document["begin"].to(Date.self) else {
            return nil
        }
        
        return PKReservation(id: id, space: space, user: user, begin: begin)
    }
}

/*
public var detailedJSON: JSON {
    return [
        "_id": _id!.hexString
    ]
}

/// 唯一識別碼
public let _id: ObjectId?

// MARK: 資料

public init() {
    _id = nil
}

static func deserialize(from primitive: Primitive) -> PKReservation? {
    guard let document = primitive.toDocument(requiredKeys: []) else {
        return nil
    }
    
    return PKReservation()
}
*/

import Foundation
import Security
import MongoKitten
import SwiftyJSON
import BSON
import Common
import PKAutoSerialization

public struct PKParking: PKModel {
    public var detailedJSON: JSON {
        let formatter = ISO8601DateFormatter()
        return JSON([
            "_id": JSON(stringLiteral: _id!.hexString),
            "space": space.fetch().0!.detailedJSON,
            "plate": JSON(stringLiteral: plate!),
            "begin": JSON(formatter.string(from: begin))
        ] as [String: JSON])
    }
    
    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    public let space: PKDbRef<PKSpace>
    public let user: PKDbRef<PKUser>
    public let plate: String?
    
    public let begin: Date
    
    private init(id: ObjectId, space s: PKDbRef<PKSpace>, user u: PKDbRef<PKUser>, plate p: String, begin b: Date) {
        _id = id
        space = s
        user = u
        plate = p
        begin = b
    }
    
    public init(spaceId: ObjectId, userId: ObjectId, plate p: String, begin b: Date) {
        _id = nil
        
        space = PKDbRef(id: spaceId, collectionName: "spaces")
        user = PKDbRef(id: userId, collectionName: "users")
        plate = p
        begin = b
    }
    
    public static func deserialize(from primitive: Primitive) -> PKParking? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "space", "user", "begin", "plate"]),
            let id = document["_id"].to(ObjectId.self),
            let space = document["space"].to(PKDbRef<PKSpace>.self),
            let user = document["user"].to(PKDbRef<PKUser>.self),
            let plate = document["plate"].to(String.self),
            let begin = document["begin"].to(Date.self) else {
                return nil
        }
        
        return PKParking(id: id, space: space, user: user, plate: plate, begin: begin)
    }
}

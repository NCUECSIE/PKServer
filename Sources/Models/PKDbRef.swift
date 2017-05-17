import PKAutoSerialization
import ResourceManager
import MongoKitten
import BSON
import Common

/// 表示 MongoDB 的文件參照
/// - Note: 不支援跨資料庫的參照
public struct PKDbRef<T>: PKPrimitiveConvertible where T: Primitive {
    public static var database: Database {
        return PKResourceManager.shared.database
    }
    
    public let _id: ObjectId
    public let collectionName: String
    
    public init(id: ObjectId, collectionName col: String) {
        _id = id
        collectionName = col
    }
    
    public lazy var document: (T?, PKServerError?) = self.fetch()
    
    public func fetch() -> (T?, PKServerError?) {
        let collection = PKDbRef.database[collectionName]
        do {
            guard let result = try collection.findOne("_id" == _id) else {
                // 1. 找不到
                return (nil, nil)
            }
            // 2. 找到了！嘗試轉換為 Primitive
            guard let deserialized = result as? T else {
                // 轉換失敗
                return (nil, PKServerError.deserialization(data: "subdocument", while: "trying to resolve a subdocument"))
            }
            return (deserialized, nil)
        } catch {
            // 資料庫錯誤
            return (nil, PKServerError.database(while: "trying to resolve a subdocument"))
        }
    }
    public func serialize() throws -> Primitive {
        return [
            "$ref": collectionName,
            "$id": _id
            ] as Document
    }
    public static func deserialize(from: Primitive) -> PKDbRef<T>? {
        guard let document = from.toDocument(requiredKeys: ["$ref", "$id"]),
            let ref = document["$ref"].to(String.self),
            let id = document["$id"].to(ObjectId.self) else {
                return nil
        }
        return PKDbRef(id: id, collectionName: ref)
    }
    
    // MARK: 資料型態不支援 Convertible
    public func convert<DT>(to type: DT.Type) -> DT.SupportedValue? where DT : DataType {
        return nil
    }
}

public extension PKDbRef where T: PKPrimitiveConvertible {
    public func fetch() -> (T?, PKServerError?) {
        let collection = PKDbRef.database[collectionName]
        do {
            guard let result = try collection.findOne("_id" == _id) else {
                // 1. 找不到
                return (nil, nil)
            }
            // 2. 找到了！嘗試轉換為 Primitive
            guard let deserialized = T.deserialize(from: result) else {
                // 轉換失敗
                return (nil, PKServerError.deserialization(data: "subdocument", while: "trying to resolve a subdocument"))
            }
            return (deserialized, nil)
        } catch {
            // 資料庫錯誤
            return (nil, PKServerError.database(while: "trying to resolve a subdocument"))
        }
    }
}

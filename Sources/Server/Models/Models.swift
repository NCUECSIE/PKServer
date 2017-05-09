import Foundation
import HeliumLogger
import MongoKitten
import PKAutoSerialization

/// 表示文件的來源
enum PKDocumentSource {
    /// 文件是由應用程式手動產生
    case code
    
    /// 文件是從資料庫中讀取
    case database
}

/// 表示文件的編輯狀態
enum PKDocumentCleaness {
    /// 文件從資料庫讀取後，尚未改變
    case clean
    
    /// 文件已經被更改過，與資料庫內的版本不同
    case dirty
}

protocol PKModel: PKObjectReflectionSerializable {
    var _id: ObjectId? { get }
}

/// 表示 MongoDB 的文件參照
/// - Note: 不支援跨資料庫的參照
struct PKDbRef<T>: PKPrimitiveConvertible where T: Primitive {
    public static var database: Database {
        return PKResourceManager.shared.database
    }
    
    public let _id: ObjectId
    public let collectionName: String
    
    init(id: ObjectId, collectionName col: String) {
        _id = id
        collectionName = col
    }
    
    public lazy var document: (T?, PKServerError?) = self.fetch()
    
    func fetch() -> (T?, PKServerError?) {
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
    func serialize() throws -> Primitive {
        return [
            "$ref": collectionName,
            "$id": _id
        ] as Document
    }
    static func deserialize(from: Primitive) -> PKDbRef<T>? {
        guard let document = from.toDocument(requiredKeys: ["$ref", "$id"]),
              let ref = document["$ref"].to(String.self),
              let id = document["$id"].to(ObjectId.self) else {
            return nil
        }
        return PKDbRef(id: id, collectionName: ref)
    }
    
    // MARK: 資料型態不支援 Convertible
    func convert<DT>(to type: DT.Type) -> DT.SupportedValue? where DT : DataType {
        return nil
    }
}

extension PKDbRef where T: PKPrimitiveConvertible {
    func fetch() -> (T?, PKServerError?) {
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

import Foundation
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
    var __source: PKDocumentSource { get }
    var __cleaness: PKDocumentCleaness { get }
    var _id: ObjectId? { get }
}

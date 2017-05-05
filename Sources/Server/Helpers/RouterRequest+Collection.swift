import Kitura
import MongoKitten

extension RouterRequest {
    /// 在 `PKResourceManager` 所指定的資料集
    var collection: MongoKitten.Database {
        return PKResourceManager.shared.collection
    }
    
    /// 在 ``PKResourceManager` 所連線的 MongoDB 伺服器
    var mongodbServer: MongoKitten.Server {
        return PKResourceManager.shared.mongodbServer
    }
}

import Kitura
import MongoKitten

public extension RouterRequest {
    /// 在 `PKResourceManager` 所指定的資料集
    public var database: MongoKitten.Database {
        return PKResourceManager.shared.database
    }
    
    /// 在 ``PKResourceManager` 所連線的 MongoDB 伺服器
    public var mongodbServer: MongoKitten.Server {
        return PKResourceManager.shared.mongodbServer
    }
}

import Kitura
import MongoKitten

/**
 管理應用程式的共享資源
 
 - Important:
 一個應用程式執行時期只能有一個 `PKResourceManager`
 */
class PKResourceManager: RouterMiddleware {
    /// 共享的實例
    public private(set) static var shared: PKResourceManager!
    
    /// 設定
    internal let config: PKSharedConfig
    
    /// MongoDB 的資料集
    public let mongodbServer: MongoKitten.Server
    public let database: MongoKitten.Database
    // public private(set) var redisServer: Void?
    
    /**
     若是已經有一個 `PKResourceManager` 時會失敗
     - Parameters:
       - mongoClientSettings: MongoDB 客戶端的設定
       - collectionName: MongoDB 的資料集名稱
     */
    init?(mongoClientSettings mongo: MongoKitten.ClientSettings, databaseName: String, config cfg: PKSharedConfig) {
        if PKResourceManager.shared != nil {
            return nil
        }
        
        guard let server = try? MongoKitten.Server(mongo) else {
            return nil
        }
        mongodbServer = server
        database = server[databaseName]
        config = cfg
        
        // MARK: 用 HeliumLogger
        // TODO: 想辦法將這個放在一個比較模組化的地方
        mongodbServer.logger = MongoKittenLoggerAPIWrapper()
        
        PKResourceManager.shared = self
    }
    
    func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        if !mongodbServer.isConnected {
            throw PKServerError.databaseNotConnected
        } else {
            next()
        }
    }
}

internal struct PKSharedConfig {
    internal private(set) var facebookAppId: String
    internal private(set) var facebookClientAccessToken: String
    internal private(set) var facebookSecret: String
}

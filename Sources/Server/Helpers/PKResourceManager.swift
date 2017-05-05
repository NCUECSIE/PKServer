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
    
    /// MongoDB 的資料集
    public private(set) var mongodbServer: MongoKitten.Server
    public private(set) var collection: MongoKitten.Database
    // public private(set) var redisServer: Void?
    
    /**
     若是已經有一個 `PKResourceManager` 時會失敗
     - Parameters:
       - mongoClientSettings: MongoDB 客戶端的設定
       - collectionName: MongoDB 的資料集名稱
     */
    init?(mongoClientSettings mongo: MongoKitten.ClientSettings, collectionName: String) {
        if PKResourceManager.shared != nil {
            return nil
        }
        
        guard let server = try? MongoKitten.Server(mongo) else {
            return nil
        }
        mongodbServer = server
        collection = server[collectionName]
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

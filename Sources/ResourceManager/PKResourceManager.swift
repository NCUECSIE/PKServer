import Kitura
import MongoKitten
import SwiftRedis
import Dispatch
import Foundation

// MARK: Internal Modules
import Utilities
import Common

/**
 管理應用程式的共享資源
 
 - Important:
 一個應用程式執行時期只能有一個 `PKResourceManager`
 */
public class PKResourceManager: RouterMiddleware {
    /// 共享的實例
    public private(set) static var shared: PKResourceManager!
    
    /// 設定
    public let config: PKSharedConfig
    
    /// MongoDB 的資料集
    public let mongodbServer: MongoKitten.Server
    public let database: MongoKitten.Database
    public private(set) var redis: Redis
    
    /**
     若是已經有一個 `PKResourceManager` 時會失敗
     - Parameters:
       - mongoClientSettings: MongoDB 客戶端的設定
       - collectionName: MongoDB 的資料集名稱
     */
    public init?(mongoClientSettings mongo: MongoKitten.ClientSettings, databaseName: String, redisConfig: (host: String, port: Int32),config cfg: PKSharedConfig) {
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
        redis = Redis()
        
        let group = DispatchGroup()
        var redisError: NSError? = nil
        group.enter()
        redis.connect(host: redisConfig.host, port: redisConfig.port) { err in
            group.leave()
            redisError = err
        }
        
        group.wait()
        if redisError != nil {
            return nil
        }
        
        PKResourceManager.shared = self
    }
    
    public func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        if !mongodbServer.isConnected {
            throw PKServerError.databaseNotConnected
        } else {
            next()
        }
    }
}

public struct PKSharedConfig {
    public private(set) var facebookAppId: String
    public private(set) var facebookClientAccessToken: String
    public private(set) var facebookSecret: String
    
    public init(facebookAppId fbId: String, facebookClientAccessToken fbToken: String, facebookSecret fbSecret: String) {
        facebookAppId = fbId
        facebookClientAccessToken = fbToken
        facebookSecret = fbSecret
    }
}

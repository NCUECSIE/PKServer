import MongoKitten
import Configuration
import XCTest
import ResourceManager

func createTestDatabaseAndResourceManager() throws -> MongoKitten.Database {
    // MARK: 從資料庫載入設定
    let configurationManager = ConfigurationManager()
    configurationManager.load(file: "./../../config.json")
    
    guard let configs = configurationManager.getConfigs() as? [String: Any],
        let mongodb = configs["mongodb"] as? [String: Any],
        let mongodbHost = mongodb["host"] as? String,
        let mongodbPort = mongodb["port"] as? UInt16,
        let facebook = configs["facebook"] as? [String: String],
        let facebookAppId = facebook["appId"],
        let facebookAppSecret = facebook["secret"] else {
            XCTFail("No configuration found.")
            throw NSError()
    }
    
    let mongodbSettings = ClientSettings(host: MongoHost(hostname: mongodbHost, port: mongodbPort), sslSettings: nil, credentials: nil)
    
    guard let server = try? MongoKitten.Server(mongodbSettings) else {
        XCTFail("Connection to MongoDB failed.")
        throw NSError()
    }
    
    let number = arc4random()
    let dbName = "__\(number)__parking_unit_test"
    
    _ = PKResourceManager(mongoClientSettings: mongodbSettings, databaseName: dbName, config: PKSharedConfig(facebookAppId: facebookAppId, facebookClientAccessToken: "", facebookSecret: facebookAppSecret))
    
    return server[dbName]
}

import MongoKitten
import LoggerAPI
import Kitura
import HeliumLogger
import Configuration
import KituraWebSocket
import WebSocketServices

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

// MARK: Internal Modules
import ResourceManager
import Middlewares
import Routers
import Common

HeliumLogger.use(LoggerMessageType.debug)

let configurationManager = ConfigurationManager()
configurationManager.load(file: "./../../config.json")

guard let configs = configurationManager.getConfigs() as? [String: Any],
      let mongodb = configs["mongodb"] as? [String: Any],
      let mongodbHost = mongodb["host"] as? String,
      let mongodbPort = mongodb["port"] as? UInt16,
      let mongodbDatabase = mongodb["database"] as? String,
      let facebook = configs["facebook"] as? [String: String],
      let facebookSecret = facebook["secret"],
      let facebookAppId = facebook["appId"],
      let facebookClientAccessToken = facebook["clientAccessToken"] else {
    let schema = [
        "{",
        "    \"mongodb\": {",
        "        \"host\": \"127.0.0.1\",",
        "        \"port\": 27017,",
        "        \"database\": \"parking\"",
        "    },",
        "    \"facebook\": {",
        "        \"secret\": \"your-facebook-app-secret\",",
        "        \"appId\": \"your-facebook-app-id\",",
        "        \"clientAccessToken\": \"your-facebook-app-client-access-token\"",
        "    }",
        "}"
    ]
    Log.error("Your configuration file should have the following format: ")
    Log.error(schema.joined(separator: "\n"))
    exit(1)
}

let sharedConfig = PKSharedConfig(facebookAppId: facebookAppId, facebookClientAccessToken: facebookClientAccessToken, facebookSecret: facebookSecret)
let mongodbSettings = ClientSettings(host: MongoHost(hostname: mongodbHost, port: mongodbPort), sslSettings: nil, credentials: nil)
guard let resourceManager = PKResourceManager(mongoClientSettings: mongodbSettings, databaseName: mongodbDatabase, config: sharedConfig) else {
    Log.error("Failed to connect to database.")
    exit(1)
}

let router = Router()
router.all(middleware: BodyParser(), resourceManager, AuthenticationMiddleware())
router.all("stats", allowPartialMatch: true, middleware: statsRouter())
router.all("me", allowPartialMatch: true, middleware: meRouter())
router.all("auth", allowPartialMatch: true, middleware: authRouter())
router.all("providers", allowPartialMatch: true, middleware: providersRouter())
router.all("spaces", allowPartialMatch: true, middleware: spacesRouter())

router.error() {
    request, response, next in
    if response.error as? PKServerError == nil {
        response.error = PKServerError.unknown(description: "Unknown error. Please check code!")
    }
    
    let error = response.error! as! PKServerError
    response.status(error.response.code).send(json: ["error": error.response.message, "code": error.response.errorCode])
}

router.get("", handler: { _, res, _ in
    res.send("Kitura running...")
})

WebSocket.register(service: SensorService(), onPath: "sensor")
Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

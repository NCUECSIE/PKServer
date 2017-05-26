import MongoKitten
import LoggerAPI
import Kitura
import HeliumLogger
import Configuration
import KituraWebSocket
import WebSocketServices
import Foundation

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

// For debug purposes only!
router.get("sensor", handler: { _, res, _ in
    let before = "<html><body>"
    let after  = "</html></after>"
    if let lastReceived = SensorService.lastReceived {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.locale = Locale(identifier: "zh-TW")
        
        switch lastReceived {
        case let .Binary(data, date):
            res.send(before + "You have sent binary data of \(data.count) bytes on \(date) <br/>" +
                "The following is the content: <br/>" +
                "<pre>\(data.map { $0 })</pre>" + after)
        case let .JSON(json, date):
            res.send(before + "You have sent String data that is serializable to JSON on \(date) <br/>" +
                "The following is the content: <br/>" +
                "<pre>\(json.rawString(encoding: .utf8, options: .prettyPrinted) ?? "conversion to string failed")</pre>" + after)
        case let .String(string, date):
            res.send(before + "You have sent String data that is not serializable to JSON on \(date) <br/>" +
                "The following is the content: <br/>" +
                "<pre>\(string)</pre>" + after)
        }
    } else {
        res.send("Nothing received yet.")
    }
})

// Override the default page
router.get("", handler: { req, res, next in
    res.send([
        "<html>",
        "<body>",
        "<p>The following HTTP routes are available for debugging your applications, </p>",
        "<ul>",
        "<li><pre>/sensor</pre> - For Sensor WebSocket API, you can view the last submitted result here.</li>",
        "</ul>",
        "</body>",
        "</html>"].joined(separator: ""))
})

WebSocket.register(service: SensorService(), onPath: "sensor")
Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

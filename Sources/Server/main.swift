import MongoKitten
import LoggerAPI
import Kitura
import HeliumLogger
import Configuration
import KituraWebSocket
import WebSocketServices
import Foundation
import Models
import Security

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
      let redis = configs["redis"] as? [String: Any],
      let redisHost = redis["host"] as? String,
      let redisPort = redis["port"] as? Int32,
      let facebook = configs["facebook"] as? [String: String],
      let facebookSecret = facebook["secret"],
      let facebookAppId = facebook["appId"],
      let facebookClientAccessToken = facebook["clientAccessToken"],
      let apns = configs["apns"] as? [String: String],
      let identityFilePath = apns["identity"],
      let identityPasspharase = apns["passphrase"],
      let bundleId = apns["bundleId"] else {
    let schema = [
        "{",
        "    \"mongodb\": {",
        "        \"host\": \"127.0.0.1\",",
        "        \"port\": 27017,",
        "        \"database\": \"parking\"",
        "    },",
        "    \"redis\": {",
        "        \"host\": \"127.0.0.1\",",
        "        \"port\": 27017,",
        "    },",
        "    \"facebook\": {",
        "        \"secret\": \"your-facebook-app-secret\",",
        "        \"appId\": \"your-facebook-app-id\",",
        "        \"clientAccessToken\": \"your-facebook-app-client-access-token\"",
        "    }",
        "    \"apns\": {",
        "        \"identity\": \"absolute path to p12 identity\",",
        "        \"passphrase\": \"pass phrase of identity file\",",
        "        \"bundleId\": \"bundle id of target application\"",
        "    }",
        "}"
    ]
    Log.error("Your configuration file should have the following format: ")
    Log.error(schema.joined(separator: "\n"))
    exit(1)
}

let sharedConfig = PKSharedConfig(facebookAppId: facebookAppId, facebookClientAccessToken: facebookClientAccessToken, facebookSecret: facebookSecret)
let mongodbSettings = ClientSettings(host: MongoHost(hostname: mongodbHost, port: mongodbPort), sslSettings: nil, credentials: nil)
guard let resourceManager = PKResourceManager(mongoClientSettings: mongodbSettings, databaseName: mongodbDatabase, redisConfig: (host: redisHost, port: redisPort), config: sharedConfig) else {
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
router.all("sensors", allowPartialMatch: true, middleware: sensorsRouter())
router.all("networks", allowPartialMatch: true, middleware: networksRouter())
router.all("reservations", allowPartialMatch: true, middleware: reservationsRouter())
router.all("parking", allowPartialMatch: true, middleware: parkingRouter())
router.all("records", allowPartialMatch: true, middleware: recordsRouter())
router.all("invoices", allowPartialMatch: true, middleware: invoicesRouter())

router.error() {
    request, response, next in
    if response.error as? PKServerError == nil {
        response.error = PKServerError.unknown(description: "Unknown error. Please check code!")
    }
    
    let error = response.error! as! PKServerError
    response.status(error.response.code).send(json: ["error": error.response.message, "code": error.response.errorCode])
}


// MARK: 偵錯用
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
router.get("", handler: { req, res, next in
    res.send([
        "<html>",
        "  <body>",
        "    <p>The following HTTP routes are available for debugging your applications, </p>",
        "    <ul>",
        "      <li><a href=\"/sensor\"></a> - For Sensor WebSocket API, you can view the last submitted result here.</li>",
        "    </ul>",
        "  </body>",
        "  <style>",
        "    a { font-family: monospace; }",
        "    a::after { content: attr(href); }",
        "  </style>",
        "</html>"].joined(separator: "\n"))
})

WebSocket.register(service: SensorService(), onPath: "sensor")
WebSocket.register(service: AppService(), onPath: "app")
Kitura.addHTTPServer(onPort: 8080, with: router)

// MARK: Redis
private enum RedisUpdateType {
    case occupied
    case unoccupied
}
private func redisUpdate(_ type: RedisUpdateType) -> (Notification) -> Void {
    return { notification in
        let userInfo = notification.userInfo!
        let spaceId = userInfo["spaceId"] as! ObjectId
        switch type {
        case .occupied:
            resourceManager.redis.set(spaceId.hexString, value: "true") { _ in }
        case .unoccupied:
            resourceManager.redis.set(spaceId.hexString, value: "false") { _ in }
        }
    }
}
NotificationCenter.default.addObserver(forName: PKNotificationType.spaceReserved.rawValue, object: nil, queue: nil, using: redisUpdate(.occupied))
NotificationCenter.default.addObserver(forName: PKNotificationType.spaceParked.rawValue, object: nil, queue: nil, using: redisUpdate(.occupied))
NotificationCenter.default.addObserver(forName: PKNotificationType.spaceFreed.rawValue, object: nil, queue: nil, using: redisUpdate(.unoccupied))

// MARK: Notification
class AuthDelegate: NSObject, URLSessionDelegate {
    var privateCredential: URLCredential!
    let bundleId: String
    
    public init(filePath: String, passphrase pass: String, bundleId id: String) {
        bundleId = id
        privateCredential = nil
        super.init()
        
        privateCredential = get_credential(filePath, passphrase: pass)
    }

    func get_credential(_ path: String, passphrase: String) -> URLCredential {
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))
        var itemsRef: CFArray? = nil
        
        _ = SecPKCS12Import(data as CFData, [kSecImportExportPassphrase: passphrase as NSString] as NSDictionary as CFDictionary, &itemsRef)
        
        let items = itemsRef! as! Array<Dictionary<String, Any>>
        let item = items[0]
        let identity = item[kSecImportItemIdentity as String]! as! SecIdentity
        
        var certificateRef: SecCertificate? = nil
        SecIdentityCopyCertificate(identity, &certificateRef)
        let certificate = certificateRef!
        let persistence = URLCredential.Persistence.forSession
        
        return URLCredential(identity: identity, certificates: [certificate], persistence: persistence)
    }
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void){
        
        var disposition: URLSession.AuthChallengeDisposition = URLSession.AuthChallengeDisposition.performDefaultHandling
        
        var credential:URLCredential?
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            
            if (credential != nil) {
                disposition = URLSession.AuthChallengeDisposition.useCredential
            }
            else{
                disposition = URLSession.AuthChallengeDisposition.performDefaultHandling
            }
        } else {
            disposition = URLSession.AuthChallengeDisposition.useCredential
            credential = privateCredential
        }
        
        completionHandler(disposition, credential)
    }
}

let authDelegate = AuthDelegate(filePath: identityFilePath, passphrase: identityPasspharase, bundleId: bundleId)

let config = URLSessionConfiguration.default
let session = URLSession(configuration: config, delegate: authDelegate, delegateQueue: nil)

var lastQueriedPendingReservation = Date.distantPast
if #available(OSX 10.12, *) {
    let timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
        do {
            let lowerBound = lastQueriedPendingReservation
            let upperBound = Date().addingTimeInterval(-60.0 * 30.0)
            lastQueriedPendingReservation = upperBound
            
            let query = "begin" > lowerBound && "begin" < upperBound
            let reservations = try resourceManager.database["reservations"]
                .find(query)
                .flatMap { $0.to(PKReservation.self) }
                .filter { _ in true }
                .map { ($0.user.fetch().0, $0) }
            
            for (userOptional, reservation) in reservations where userOptional != nil {
                let user = userOptional!
                
                for device in user.deviceIds {
                    let url = URL(string: "https://api.development.push.apple.com/3/device/\(device)")!
                    let payload = "{ \"aps\": { \"alert\": \"hello\"}}"
                    
                    
                    var request = URLRequest(url: url)
                    request.httpBody = payload.data(using: .utf8)
                    request.addValue(bundleId, forHTTPHeaderField: "apns-topic")
                    request.httpMethod = "POST"
                    
                    session.dataTask(with: request, completionHandler: { _ in }).resume()
                }
            }
        } catch {}
    }
} else {
    Log.warning("Timer not set!")
}

Kitura.run()

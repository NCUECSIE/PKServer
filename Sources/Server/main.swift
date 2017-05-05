import MongoKitten
import Kitura
import HeliumLogger

HeliumLogger.use()

let MONGO_HOST = "127.0.0.1"
let MONGO_PORT = 32769 as UInt16
let MONGO_COLLECTION = "parking"

let mongodbSettings = ClientSettings(host: MongoHost(hostname: MONGO_HOST, port: MONGO_PORT), sslSettings: nil, credentials: nil)
let resourceManager = PKResourceManager(mongoClientSettings: mongodbSettings, collectionName: MONGO_COLLECTION)
let router = Router()

router.all(middleware: resourceManager!)
router.get("stats", allowPartialMatch: false, middleware: statsRouter())

router.error() {
    request, response, next in
    guard let error = response.error as? PKServerError else {
        response.status(.internalServerError).send(json: ["error": "Unknown error."])
        return
    }
    response.status(error.response.0).send(json: ["error": error.response.1])
}

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

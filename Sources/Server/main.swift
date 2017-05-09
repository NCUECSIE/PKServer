import MongoKitten
import Kitura
import HeliumLogger

HeliumLogger.use()

let MONGO_HOST = "127.0.0.1"
let MONGO_PORT = 32768 as UInt16
let MONGO_COLLECTION = "parking"

let FACEBOOK_SECRET = "7db6ba25a25a3f9b2ee6b3c71a9d30e6"
let FACEBOOK_APP_ID = "622685157925629"
let FACEBOOK_CLIENT_TOKEN = "72222e6e8010af46eb65ea51b89bd694"

let sharedConfig = PKSharedConfig(facebookAppId: FACEBOOK_APP_ID, facebookClientAccessToken: FACEBOOK_CLIENT_TOKEN, facebookSecret: FACEBOOK_SECRET)
let mongodbSettings = ClientSettings(host: MongoHost(hostname: MONGO_HOST, port: MONGO_PORT), sslSettings: nil, credentials: nil)
let resourceManager = PKResourceManager(mongoClientSettings: mongodbSettings, collectionName: MONGO_COLLECTION, config: sharedConfig)

let router = Router()
router.all(middleware: BodyParser(), resourceManager!, AuthenticationMiddleware())
router.all("stats", allowPartialMatch: true, middleware: statsRouter())
router.all("auth", allowPartialMatch: true, middleware: authRouter())
router.all("spaces", allowPartialMatch: true, middleware: spacesRouter())
router.all("providers", allowPartialMatch: true, middleware: providersRouter())

router.error() {
    request, response, next in
    if response.error as? PKServerError == nil {
        response.error = PKServerError.unknown(description: "Unknown error. Please check code!")
    }
    
    let error = response.error! as! PKServerError
    response.status(error.response.code).send(json: ["error": error.response.message, "code": error.response.errorCode])
}

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

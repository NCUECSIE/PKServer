import Kitura
import HeliumLogger

import MongoKitten

HeliumLogger.use()

// Create a new router
let router = Router()

struct TestError: Error {
    
}

// Handle HTTP GET requests to /
router.get("/") {
    request, response, next in
    throw TestError()
    //response.send("Hello, World!")
    
    // next()
}

router.error() {
    request, response, next in
    response.status(.internalServerError).send("Internal Server Error")
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8080, with: router)

// Start the Kitura runloop (this call never returns)
// Kitura.run()

testMongoKitten()

let collection: MongoKitten.Collection!
let document = [ "a" : "b" ]
collection.insert(Document(document)!)

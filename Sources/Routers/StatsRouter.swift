import Kitura

public func statsRouter() -> Router {
    let router = Router()
    
    router.get(handler: {request, response, next in
        let server = request.mongodbServer
        response.send(json: [
            "connected": server.isConnected,
            "description": server.description
        ])
    })
    
    return router
}


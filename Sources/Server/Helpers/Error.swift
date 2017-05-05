import KituraNet

enum PKServerError: Swift.Error {
    case databaseNotConnected
    
    var localizedDescription: String {
        switch self {
        case .databaseNotConnected:
            return "Database is not connected."
        }
    }
    
    var response: (HTTPStatusCode, String) {
        switch self {
        case .databaseNotConnected:
            return  (.internalServerError, self.localizedDescription)
        }
    }
}

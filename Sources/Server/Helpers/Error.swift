import KituraNet

enum PKServerError: Swift.Error {
    /// 資料庫尚未連項
    /// - Note: 此 Error 只有在當 `PKResourceManager` 無法連線至伺服器時被丟出
    /// - Important: 不應該在路由中丟出此
    case databaseNotConnected
    
    /// 要求中沒有提供所有需要的資料
    /// - Note: 若不打算提供更多資訊，請為 `fields` 提供空陣列
    case missingBody(fields: [(name: String, type: String)])
    
    /// 出現網路錯誤
    /// - Note: 請為 `while` 提供動名詞以及句號
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.networkError(while: "confirming your Facebook identity.")
    ///   ```
    case networkError(while: String)
    
    /// 出現資料庫錯誤
    /// - Note: 請為 `while` 提供動名詞以及句號
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.databaseError(while: "trying to fetch user data.")
    ///   ```
    case databaseError(while: String)
    
    /// 出現加密錯誤
    /// - Note: 請為 `while` 提供動名詞以及句號
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.cryptoError(while: "trying to hash your access token.")
    ///   ```
    case cryptoError(while: String)
    
    /// 出現其他錯誤
    /// - Note: 請為 `description` 完整句子
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.otherError(description: "An serialization error occured while trying to write your data to the database.")
    ///   ```
    case otherError(description: String)
    
    /// 功能尚未實作
    /// - Note: `feature` 必須為名詞
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.unimplementedError(feature: "agent and admin scope")
    ///   ```
    case unimplementedError(feature: String)
    
    /// 出現序列化錯誤
    /// - Note: `data` 為嘗試序列化的資料；`while` 為嘗試序列化的原因
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.serializationError(data: "User", while: "registering your account.")
    ///   ```
    case serializationError(data: String, while: String)
    
    /// 出現序列化錯誤
    /// - Note: `data` 為嘗試序列化的資料；`while` 為嘗試序列化的原因
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.deserializationError(data: "User", while: "fetching your account.")
    ///   ```
    case deserializationError(data: String, while: String)
    
    var localizedDescription: String {
        switch self {
        case .databaseNotConnected:
            return "Database is not connected."
        case .missingBody(_):
            return "Missing body."
        case .networkError(while: let activity):
            return "Network error occured while \(activity)"
        case .databaseError(while: let activity):
            return "Database error occured while \(activity)"
        case .cryptoError(while: let activity):
            return "Crypto error occured while \(activity)"
        case .unimplementedError(feature: let feature):
            return "The requested feature, \(feature), is not implemented."
        case .otherError(description: let description):
            return description
        case .serializationError(data: let data, while: let activity):
            return "Error serializing \(data) while \(activity)"
        case .deserializationError(data: let data, while: let activity):
            return "Error deserializing \(data) while \(activity)"
        }
    }
    
    var response: (code: HTTPStatusCode, message: String) {
        switch self {
        case .missingBody(fields: let fields):
            let fieldsDescription = fields.map { field in "\(field.name) of type \(field.type)" }.joined(separator: ", ")
            if fields.count == 0 {
                return (.badRequest, "Missing fields in body.")
            } else if fields.count == 1 {
                return (.badRequest, "Missing the following field in body: \(fieldsDescription)")
            } else {
                return (.badRequest, "Missing the following fields in body: \(fieldsDescription)")
            }
        default:
            return (.internalServerError, self.localizedDescription)
        }
    }
}

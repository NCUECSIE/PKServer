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
    ///   PKServerError.network(while: "confirming your Facebook identity.")
    ///   ```
    case network(while: String)
    
    /// 出現資料庫錯誤
    /// - Note: 請為 `while` 提供動名詞以及句號
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.database(while: "trying to fetch user data.")
    ///   ```
    case database(while: String)
    
    /// 出現加密錯誤
    /// - Note: 請為 `while` 提供動名詞以及句號
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.crypto(while: "trying to hash your access token.")
    ///   ```
    case crypto(while: String)
    
    /// 出現其他錯誤
    /// - Note: 請為 `description` 完整句子
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.unknown(description: "An serialization error occured while trying to write your data to the database.")
    ///   ```
    /// - Important: 請儘量不要使用這個 `Error`，只有當錯誤不常發生且是由使用者的惡意要求產生時使用。
    case unknown(description: String)
    
    /// 功能尚未實作
    /// - Note: `feature` 必須為名詞
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.unimplemented(feature: "agent and admin scope")
    ///   ```
    case unimplemented(feature: String)
    
    /// 出現序列化錯誤
    /// - Note: `data` 為嘗試序列化的資料；`while` 為嘗試序列化的原因
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.serialization(data: "User", while: "registering your account.")
    ///   ```
    case serialization(data: String, while: String)
    
    /// 出現序列化錯誤
    /// - Note: `data` 為嘗試序列化的資料；`while` 為嘗試序列化的原因
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.deserialization(data: "User", while: "fetching your account.")
    ///   ```
    case deserialization(data: String, while: String)
    
    /// 必須登入才能執行動作
    /// - Note: `action` 為動作的敘述
    ///
    ///   例如：
    ///   ```
    ///   PKServerError.requiredAuthentication(action: "creating a social link")
    ///   ```
    case requiresAuthentication(action: String)
    
    /// 傳入的 Token 已經過期
    ///
    /// - Note: 第一次被超時使用時傳送
    case tokenExpired
    
    /// 傳入的 Token 無法被確認
    case badToken
    
    var localizedDescription: String {
        switch self {
        case .databaseNotConnected:
            return "Database is not connected."
        case .missingBody(_):
            return "Missing body."
        case .network(while: let activity):
            return "Network error occured while \(activity)"
        case .database(while: let activity):
            return "Database error occured while \(activity)"
        case .crypto(while: let activity):
            return "Crypto error occured while \(activity)"
        case .unimplemented(feature: let feature):
            return "The requested feature, \(feature), is not implemented."
        case .unknown(description: let description):
            return description
        case .serialization(data: let data, while: let activity):
            return "Error serializing \(data) while \(activity)"
        case .deserialization(data: let data, while: let activity):
            return "Error deserializing \(data) while \(activity)"
        case .requiresAuthentication(action: let action):
            return "The action you requested, \(action), requires authentication first."
        case .tokenExpired:
            return "The token you provided is expired, and will be deleted. Please login again."
        case .badToken:
            return "The token you provided is not valid. Please authenticate again."
        }
    }
    
    var response: (code: HTTPStatusCode, message: String, errorCode: Int) {
        switch self {
        case .missingBody(fields: let fields):
            let fieldsDescription = fields.map { field in "\(field.name) of type \(field.type)" }.joined(separator: ", ")
            if fields.count == 0 {
                return (.badRequest, "Missing fields in body.", errorCode)
            } else if fields.count == 1 {
                return (.badRequest, "Missing the following field in body: \(fieldsDescription)", errorCode)
            } else {
                return (.badRequest, "Missing the following fields in body: \(fieldsDescription)", errorCode)
            }
        case .requiresAuthentication(_): fallthrough
        case .badToken: fallthrough
        case .tokenExpired:
            return (.unauthorized, self.localizedDescription, errorCode)
        default:
            return (.internalServerError, self.localizedDescription, errorCode)
        }
    }
    
    /// 錯誤的辨識碼，在客戶端可以用來辨識錯誤
    /// - Note:
    ///   1. 用 `0` ~ `9` 代表伺服器尚未就緒
    ///   2. 用 `10` ~ `99` 代表認證相關錯誤
    ///   3. 用 `100` ~ `999` 代表伺服器處理使用者資料出現問題
    ///   4. 用 `1000` ~ `9999` 代表其他或者是未實作問題
    var errorCode: Int {
        switch self {
        case .databaseNotConnected:
            return 0
        case .requiresAuthentication(_):
            return 10
        case .badToken:
            return 11
        case .tokenExpired:
            return 12
        case .missingBody(_):
            return 100
        case .network(_):
            return 101
        case .database(_):
            return 102
        case .crypto(_):
            return 103
        case .serialization(_):
            return 104
        case .deserialization(_):
            return 105
        case .unimplemented(_):
            return 1000
        case .unknown(_):
            return 1001
        }
    }
}

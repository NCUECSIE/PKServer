import Foundation
import Security
import BSON
import PKAutoSerialization

// MARK: 使用者資料型態
enum PKAccessLevel: String, PKEnumReflectionSerializable {
    case readOnly = "readOnly"
    case readWrite = "readWrite"
}
enum PKUserType: PKEnumReflectionSerializable {
    case standard
    case agent(provider: ObjectId, access: PKAccessLevel)
    case admin(access: PKAccessLevel)
    
    static func deserialize(case: String, values: [Primitive]?) -> PKUserType? {
        switch `case` {
        case "standard":
            return .standard
        case "agent":
            guard let values = values, values.count == 2,
                  let _0 = values[0].to(ObjectId.self),
                  let _1 = values[1].to(PKAccessLevel.self) else { return nil }
            return .agent(provider: _0, access: _1)
        case "admin":
            guard let values = values, values.count == 1,
                  let _0 = values[0].to(PKAccessLevel.self) else { return nil }
            return .admin(access: _0)
        default: return nil
        }
    }
}

enum PKSocialLoginProvider: String, PKEnumReflectionSerializable {
    case facebook = "facebook"
}

struct PKSocialLoginLink: PKObjectReflectionSerializable {
    let provider: PKSocialLoginProvider
    let userId: String
    var accessToken: String
    
    static func deserialize(from primitive: Primitive) -> PKSocialLoginLink? {
        guard let document = primitive.toDocument(requiredKeys: ["provider", "userId", "accessToken"]),
              let providerValue = PKSocialLoginProvider.deserialize(from: document["provider"]!),
              let userIdValue = document["userId"]!.to(String.self),
              let accessTokenValue = document["accessToken"]!.to(String.self) else { return nil }
        
        return PKSocialLoginLink(provider: providerValue, userId: userIdValue, accessToken: accessTokenValue)
    }
}

enum PKTokenScope: PKEnumReflectionSerializable, Equatable {
    case standard
    case agent(provider: ObjectId)
    case admin
    
    static func deserialize(case: String, values: [Primitive]?) -> PKTokenScope? {
        switch `case` {
        case "standard":
            return .standard
        case "agent":
            guard let values = values, values.count == 1,
                let _0 = values[0].to(ObjectId.self) else { return nil }
            return .agent(provider: _0)
        case "admin":
            return .admin
        default: return nil
        }
    }
    static func ==(lhs: PKTokenScope, rhs: PKTokenScope) -> Bool {
        switch (lhs, rhs) {
        case (.standard, .standard):
            return true
        case (.agent(let lhs_agent), .agent(let rhs_agent)):
            if lhs_agent == rhs_agent {
                return true
            } else {
                return false
            }
        case (.admin, .admin):
            return true
        default:
            return false
        }
    }
}
struct PKToken: PKObjectReflectionSerializable {
    let value: String
    let issued: Date
    let expires: Date
    let scope: PKTokenScope
    
    static func deserialize(from primitive: Primitive) -> PKToken? {
        guard let document = primitive.toDocument(requiredKeys: ["value", "issued", "expires", "scope"]),
              let v = document["value"]?.to(String.self),
              let i = document["issued"]?.to(Date.self),
              let e = document["expires"]?.to(Date.self),
              let s = document["scope"]?.to(PKTokenScope.self) else { return nil }
        return PKToken(value: v, issued: i, expires: e, scope: s)
    }
}

struct PKUser: PKModel {
    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    /// 使用者類型
    public var types: [PKUserType]
    /// 使用者登入方法
    public var links: [PKSocialLoginLink]
    /// APNS 裝置 ID
    public var deviceIds: [String]
    /// 使用者認證代幣
    public var tokens: [PKToken]
    
    public init(_ type: PKUserType, initialLink link: PKSocialLoginLink) {
        _id = nil
        types = [type]
        links = [link]
        deviceIds = []
        tokens = []
    }
    
    /// 產生新的 Token，放進 `PKUser.tokens` 但是並不會更新資料庫上的資訊
    /// - Returns: 產生的 Token
    public mutating func createNewToken(of scope: PKTokenScope) -> PKToken {
        let random = randomBytes(length: 32).base64EncodedString()
        let token = PKToken(value: random, issued: Date(), expires: Date().addingTimeInterval(3600.0 * 24.0 * 7.0), scope: scope)
        tokens.append(token)
        
        return token
    }
    
    private init(_id i: ObjectId, types ty: [PKUserType], links l: [PKSocialLoginLink], deviceIds d: [String], tokens to: [PKToken]) {
        _id = i
        types = ty
        links = l
        deviceIds = d
        tokens = to
    }
    
    static func deserialize(from primitive: Primitive) -> PKUser? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "types", "links", "deviceIds", "tokens"]),
              let _idValue = document["_id"]!.to(ObjectId.self),
              let typesValue = document["types"]!.toArray(typed: PKUserType.self),
              let linksValue = document["links"]!.toArray(typed: PKSocialLoginLink.self),
              let deviceIdsValue = document["deviceIds"]!.toArray(typed: String.self),
              let tokensValue = document["tokens"]!.toArray(typed: PKToken.self) else { return nil }
        return PKUser(_id: _idValue, types: typesValue, links: linksValue, deviceIds: deviceIdsValue, tokens: tokensValue)
    }
}

func randomBytes(length: Int) -> Data {
    var data = Data(count: length)
    let result = data.withUnsafeMutableBytes { bytes in SecRandomCopyBytes(kSecRandomDefault, length, bytes) }
    if result == errSecSuccess {
        return data
    } else {
        fatalError("Cannot generate random bytes.")
    }
    return data
}

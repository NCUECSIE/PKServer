import Foundation
import Security
import MongoKitten
import SwiftyJSON
import BSON
import Common
import PKAutoSerialization

// MARK: 使用者資料型態
public enum PKAccessLevel: String, PKEnumReflectionSerializable {
    case readOnly = "readOnly"
    case readWrite = "readWrite"
}
public enum PKUserType: PKEnumReflectionSerializable {
    case standard
    case agent(provider: ObjectId, access: PKAccessLevel)
    case admin(access: PKAccessLevel)
    
    public static func deserialize(case: String, values: [Primitive]?) -> PKUserType? {
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

public struct PKSocialLoginStrategy: PKObjectReflectionSerializable {
    public let strategy: PKSocialStrategy
    public let userId: String
    public var accessToken: String
    
    public init(strategy s: PKSocialStrategy, userId uid: String, accessToken token: String) {
        strategy = s
        userId = uid
        accessToken = token
    }
    
    public static func deserialize(from primitive: Primitive) -> PKSocialLoginStrategy? {
        guard let document = primitive.toDocument(requiredKeys: ["strategy", "userId", "accessToken"]),
              let strategyValue = PKSocialStrategy.deserialize(from: document["strategy"]!),
              let userIdValue = document["userId"]!.to(String.self),
              let accessTokenValue = document["accessToken"]!.to(String.self) else { return nil }
        
        return PKSocialLoginStrategy(strategy: strategyValue, userId: userIdValue, accessToken: accessTokenValue)
    }
}

public enum PKTokenScope: PKEnumReflectionSerializable, Equatable {
    case standard
    case agent(provider: ObjectId)
    case admin
    
    public static func deserialize(case: String, values: [Primitive]?) -> PKTokenScope? {
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
    public static func ==(lhs: PKTokenScope, rhs: PKTokenScope) -> Bool {
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
public struct PKToken: PKObjectReflectionSerializable {
    public let value: String
    public let issued: Date
    public let expires: Date
    public let scope: PKTokenScope
    
    public static func deserialize(from primitive: Primitive) -> PKToken? {
        guard let document = primitive.toDocument(requiredKeys: ["value", "issued", "expires", "scope"]),
              let v = document["value"]?.to(String.self),
              let i = document["issued"]?.to(Date.self),
              let e = document["expires"]?.to(Date.self),
              let s = document["scope"]?.to(PKTokenScope.self) else { return nil }
        return PKToken(value: v, issued: i, expires: e, scope: s)
    }
}

public struct PKUser: PKModel {
    public var detailedJSON: JSON {
        fatalError()
    }

    /// 唯一識別碼
    public let _id: ObjectId?
    
    // MARK: 資料
    /// 使用者類型
    public var types: [PKUserType]
    /// 使用者登入方法
    public var strategies: [PKSocialLoginStrategy]
    /// APNS 裝置 ID
    public var deviceIds: [String]
    /// 車輛 ID
    public var vehicleIds: [String]
    /// 使用者認證代幣
    public var tokens: [PKToken]
    
    public init(initialStrategy strategy: PKSocialLoginStrategy) {
        _id = nil
        types = [.standard]
        strategies = [strategy]
        deviceIds = []
        vehicleIds = []
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
    
    private init(_id i: ObjectId, types ty: [PKUserType], strategies s: [PKSocialLoginStrategy], deviceIds d: [String], vehicleIds v: [String], tokens to: [PKToken]) {
        _id = i
        types = ty
        strategies = s
        deviceIds = d
        vehicleIds = v
        tokens = to
    }
    
    internal init?(from collection: MongoKitten.Collection, id: ObjectId) {
        do {
            let deserialized = PKUser.deserialize(from: try collection.findOne("_id" == id))
            if deserialized == nil { return nil }
            self = deserialized!
        } catch {
            return nil
        }
    }
    
    public static func deserialize(from primitive: Primitive) -> PKUser? {
        guard let document = primitive.toDocument(requiredKeys: ["_id", "types", "strategies", "deviceIds", "vehicleIds", "tokens"]),
              let _idValue = document["_id"]!.to(ObjectId.self),
              let typesValue = document["types"]!.toArray(typed: PKUserType.self),
              let strategiesValue = document["strategies"]!.toArray(typed: PKSocialLoginStrategy.self),
              let deviceIdsValue = document["deviceIds"]!.toArray(typed: String.self),
              let vehicleIdsValue = document["vehicleIds"]!.toArray(typed: String.self),
              let tokensValue = document["tokens"]!.toArray(typed: PKToken.self) else { return nil }
        return PKUser(_id: _idValue, types: typesValue, strategies: strategiesValue, deviceIds: deviceIdsValue, vehicleIds: vehicleIdsValue, tokens: tokensValue)
    }
}

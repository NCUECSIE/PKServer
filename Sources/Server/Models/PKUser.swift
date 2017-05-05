import Foundation
import BSON

// MARK: 使用者資料型態
enum PKAccessLevel: String {
    case readOnly = "readOnly"
    case readWrite = "readWrite"
}

enum PKUserType {
    case standard
    case agent(provider: ObjectId, access: PKAccessLevel)
    case admin(access: PKAccessLevel)
}

enum SocialLoginProvider {
    case facebook
}

struct SocialLoginLink {
    let provider: SocialLoginProvider
    let userId: String
    var accessToken: String
}

struct PKUser {
    // MARK: 支援 PKAutoSerializableDocument
    public private(set) var __cleaness: PKDocumentCleaness
    public private(set) var __source: PKDocumentSource
    public let _id: ObjectId?
    
    // MARK: 資料
    var types: [PKUserType]
    var links: [SocialLoginLink]
    
    // MARK: 測試用
    var int: Int
    var double: Double
    var string: String
    var bool: Bool
    
    public init(_ type: PKUserType, initialLink link: SocialLoginLink) {
        __cleaness = .dirty
        __source = .code
        _id = nil
        
        types = [type]
        links = [link]
        
        int = -5
        double = 1.76
        string = "Hello Me?"
        bool = false
    }
}

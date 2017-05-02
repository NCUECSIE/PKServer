import Foundation
import MongoKitten

/// 表示文件的來源
enum PKDocumentSource {
    /// 文件是由應用程式手動產生
    case code
    
    /// 文件是從資料庫中讀取
    case database
}

/// 表示文件的編輯狀態
enum PKDocumentCleaness {
    /// 文件從資料庫讀取後，尚未改變
    case clean
    
    /// 文件已經被更改過，與資料庫內的版本不同
    case dirty
}

protocol PKAutoSerializableDocument: PKAutoSerializableValue {
    var __source: PKDocumentSource { get }
    var __cleaness: PKDocumentCleaness { get }
    var _id: ObjectId? { get }
}

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

struct PKUser: PKAutoSerializableDocument {
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
protocol PKAutoSerializableValue {}
extension PKAutoSerializableValue {
//    func serialized() -> Any {
//        
//    }
}

enum PKSerializationError: Error {
    case unsupportedType
}

func serialize(_ `self`: Any) throws -> Primitive {
    let mirror = Mirror(reflecting: self)
    let type = mirror.subjectType
    let family = mirror.displayStyle
    
    if type == Int.self {
        return self as! Int
    } else if type == Double.self {
        return self as! Double
    } else if type == String.self {
        return self as! String
    } else if type == Bool.self {
        return self as! Bool
    } else if let family = family {
        switch family {
        case .enum:
            var rawValue = "\(self)"
            if let leftParenthesis = rawValue.range(of: "(") {
                rawValue = rawValue.substring(to: leftParenthesis.lowerBound)
            }
            
            if mirror.children.isEmpty {
                return rawValue
            } else {
                return [ "case": rawValue, "values": try serialize(mirror.children.first!.value) ]
            }
        case .class: fallthrough
        case .struct:
            var dictionary: [String: Any] = [:]
            for (k, v) in mirror.children where !k!.hasPrefix("__") {
                dictionary[k!] = try serialize(v)
            }
            return dictionary
        case .set: fallthrough
        case .collection:
            var array: [Any] = []
            for (_, value) in mirror.children {
                array.append(try serialize(value))
            }
            return array
        case .optional:
            if let some = mirror.children.first {
                return try serialize(some.value)
            } else {
                return Null()
            }
        case .tuple:
            if mirror.children.first?.label != nil {
                fallthrough
            }
            var array: [Any] = []
            for (_, value) in mirror.children {
                array.append(try serialize(value))
            }
            return array
        case .dictionary:
            var dictionary: [String: Any] = [:]
            for (k, v) in mirror.children where !k!.hasPrefix("__") {
                dictionary[k!] = try serialize(v)
            }
            return dictionary
        }
    }
    
    throw PKSerializationError.unsupportedType
}

func testMongoKitten() {
//    guard let server = try? Server("mongodb://127.0.0.1:32768/") else {
//        print("Cannot connect to server")
//        return
//    }
//    let database = server["parking"]
//    if database.server.isConnected {
//        print("Successfully connected!")
//    } else {
//        print("Connection failed")
//    }
//    
//    let usersCollection = database["users"]
    
    let user = PKUser(.admin(access: .readWrite), initialLink: SocialLoginLink(provider: .facebook, userId: "facebookUserId", accessToken: "facebookAccessToken"))
    let serialized = try? serialize(user) as! [String: Primitive]
    print(Document(dictionaryElements: serialized!.array.map({ ($0.key, $0.value) })))
//    
//    guard let result = try? usersCollection.insert([
//        "int": 5,
//        "double": 2.5,
//        "date": Date(),
//        "null": Null(),
//        "str": "string",
//        "array": [1, 2, 3, 5.5, "Hello"],
//        "object": [ "a": "b", "c" : 5 ]
//    ]) else {
//        print("Insert unsuccessful")
//        return
//    }
//    
//    print("Insert successful, id = \(ObjectId(result))")
}

extension Dictionary: PKAutoSerializableValue {}
extension Array: PKAutoSerializableValue {}
extension Optional: PKAutoSerializableValue {}


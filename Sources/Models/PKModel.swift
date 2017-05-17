import Foundation
import HeliumLogger
import MongoKitten
import PKAutoSerialization
import SwiftyJSON

// MARK: Internal Modules
import Common
import ResourceManager

public protocol PKUserJSONConvertible {
    var detailedJSON: JSON { get }
    var simpleJSON: JSON { get }
}
public protocol PKAdminJSONConvertible: PKUserJSONConvertible {
    var detailedAdminJSON: JSON { get }
    var simpleAdminJSON: JSON { get }
}
public extension PKUserJSONConvertible {
    var simpleJSON: JSON { return self.detailedJSON }
}
public extension PKAdminJSONConvertible {
    var detailedAdminJSON: JSON { return self.detailedJSON }
    var simpleAdminJSON: JSON { return self.simpleJSON }
}

protocol PKModel: PKObjectReflectionSerializable, PKUserJSONConvertible, PKAdminJSONConvertible {
    var _id: ObjectId? { get }
}


import Foundation

extension Notification.Name: ExpressibleByStringLiteral {
    // MARK: ExpressibleByStringLiteral
    public typealias StringLiteralType = String
    public init(stringLiteral string: String) {
        self.init(string)
    }
    
    // MARK: 不會用到的 Protocol（從單一字元初始化）
    public typealias UnicodeScalarLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public init(extendedGraphemeClusterLiteral cluster: String) { self.init(stringLiteral: cluster) }
    public init(unicodeScalarLiteral scalar: String) { self.init(stringLiteral: scalar) }
}

public enum PKNotificationType: Notification.Name {
    /// user info: ["spaceId": ObjectId]
    case spaceReserved = "reserved"
    case spaceParked = "parked"
    case spaceFreed = "freed"
    /**
     在 userInfo 中必須有：
     [ "user": PKUser, reservation: PKReservation ]
     */
    case userReservationChanged = "userReservationChanged"
    /**
     在 userInfo 中必須有：
     [ "user": PKUser, reservation: PKReservation ]
     */
    case userReservationCancelled = "userReservationCancelled"
}

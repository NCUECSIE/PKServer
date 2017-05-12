import LoggerAPI
import MongoKitten

public struct MongoKittenLoggerAPIWrapper: MongoKitten.Logger {
    public func verbose(_ message: String) {
        Log.verbose(message)
    }
    public func debug(_ message: String) {
        Log.debug(message)
    }
    public func info(_ message: String) {
        Log.info(message)
    }
    public func warning(_ message: String) {
        Log.warning(message)
    }
    public func error(_ message: String) {
        Log.error(message)
    }
    public func fatal(_ message: String) {
        Log.error(message)
    }
    
    public init() {}
}

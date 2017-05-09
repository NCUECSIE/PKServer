import LoggerAPI
import MongoKitten

struct MongoKittenLoggerAPIWrapper: MongoKitten.Logger {
    func verbose(_ message: String) {
        Log.verbose(message)
    }
    func debug(_ message: String) {
        Log.debug(message)
    }
    func info(_ message: String) {
        Log.info(message)
    }
    func warning(_ message: String) {
        Log.warning(message)
    }
    func error(_ message: String) {
        Log.error(message)
    }
    func fatal(_ message: String) {
        Log.error(message)
    }
}

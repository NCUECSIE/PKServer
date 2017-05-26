import Foundation
import Security

public func randomBytes(length: Int) -> Data {
    var data = Data(count: length)
    let result = data.withUnsafeMutableBytes { bytes in SecRandomCopyBytes(kSecRandomDefault, length, bytes) }
    if result == errSecSuccess {
        return data
    } else {
        fatalError("Cannot generate random bytes.")
    }
    return data
}

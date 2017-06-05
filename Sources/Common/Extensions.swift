import Foundation
import CryptoSwift

public extension Data {
    init?(physicalAddress: String) {
        let bytes = physicalAddress.components(separatedBy: ":").flatMap { UInt8($0, radix: 16) }
        self.init(bytes: bytes)
        // print("Test Data Extension: ")
        // print("Physical address: ", physicalAddress)
        // print("bytes: ", bytes)
        if count != 6 { return nil }
    }
}

public extension String {
    init?(physicalAddress: Data) {
        if physicalAddress.count != 6 { return nil }
        var added = 0
        let sequence = physicalAddress.toHexString().characters.reduce([Character](), { (cs: [Character], character: Character) -> [Character] in
            var characters = cs
            
            if characters.count > 0 && (characters.count - added) % 2 == 0 {
                characters.append(":")
                added += 1
            }
            characters.append(character)
            // print("String: ")
            // print("pa: ", physicalAddress)
            // print("sequence: ", characters)
            return characters
        })
        
        self.init(sequence)
        
    }
}

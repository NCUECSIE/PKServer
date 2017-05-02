import MongoKitten


protocol PKPrimitiveConvertible: Primitive {}

/// 想要支援自動序列化的型態必須支援的協定，
/// - Note:
/// 建議 `class` 或是 `struct` 採用
protocol PKReflectionSerializable: PKPrimitiveConvertible {
    func serialize() throws -> [String: Primitive]
}

extension PKReflectionSerializable {
    var typeIdentifier: Byte { return 0x03 }
    func makeBinary() -> Bytes {
        guard let serialized = try? serialize() else {
            fatalError("Bad values in your PKReflectionSerializable data.")
        }
        return Document(dictionaryElements: serialized.array.map({ ($0.key, $0.value) })).makeBinary()
    }
    func serialize() throws -> [String: Primitive] {
        let mirror = Mirror(reflecting: self)
        if mirror.displayStyle == .class || mirror.displayStyle == .struct {
            var dictionary: [String: Primitive] = [:]
            for (key, value) in mirror.children.map({ ($0.label!, $0.value) }) where !key.hasPrefix("__") {
                // TODO: 檢查是否有 Tuple
                if let value = value as? Primitive {
                    dictionary[key] = value
                } else {
                    throw SerializationError.unsupportedValue
                }
            }
            return dictionary
        }
        
        throw SerializationError.unsupportedType
    }
}

// Enum!

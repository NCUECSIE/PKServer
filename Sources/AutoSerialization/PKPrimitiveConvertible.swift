import BSON
import MongoKitten

public protocol PKPrimitiveConvertible: Primitive {
    func serialize() throws -> Primitive
    static func deserialize(from: Primitive) -> Self?
}
public extension PKPrimitiveConvertible {
    public var typeIdentifier: Byte {
        guard let serialized = try? serialize() else { fatalError() }
        return serialized.typeIdentifier
    }
    func makeBinary() -> Bytes {
        guard let serialized = try? serialize() else {
            fatalError("Bad values in your PKReflectionSerializable data.")
        }
        return Document(data: serialized.makeBinary()).makeBinary()
    }
}

import BSON
import MongoKitten

protocol PKPrimitiveConvertible: Primitive {
    func serialize() throws -> Primitive
    static func deserialize(doc: Primitive) -> Self?
}
extension PKPrimitiveConvertible {
    func makeBinary() -> Bytes {
        guard let serialized = try? serialize() else {
            fatalError("Bad values in your PKReflectionSerializable data.")
        }
        return Document(serialized)!.makeBinary()
    }
}

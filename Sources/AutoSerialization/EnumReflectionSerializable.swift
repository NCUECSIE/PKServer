import Foundation
import BSON

protocol PKEnumReflectionSerializable: PKPrimitiveConvertible {
    func serialize() throws -> Primitive
}

extension PKEnumReflectionSerializable {
    var typeIdentifier: Byte { return 0x03 }
    func serialize() throws -> Primitive {
        let mirror = Mirror(reflecting: self)
        guard case .some(.enum) = mirror.displayStyle else {
            fatalError("Conforming identifier is not an enum")
        }
        
        var rawValue = "\(self)"
        if let leftParenthesis = rawValue.range(of: "(") {
            rawValue = rawValue.substring(to: leftParenthesis.lowerBound)
        }
        
        if mirror.children.isEmpty {
            return [ "case": rawValue ]
        } else {
            return [ "case": rawValue, "values": serializeTuple(mirror.children.first!.value) ]
        }
    }
    func convert<DT>(to type: DT.Type) -> DT.SupportedValue? where DT : DataType {
        fatalError()
    }
}

extension PKEnumReflectionSerializable where Self: RawRepresentable, Self.RawValue: Primitive {
    func serialize() throws -> Primitive {
        let mirror = Mirror(reflecting: self)
        guard case .some(.enum) = mirror.displayStyle else {
            fatalError("Conforming identifier is not an enum")
        }
        
        return [ "case": rawValue ]
    }
    static func deserialize(doc: Primitive) -> Self? {
        guard let rawValue = doc as? Self.RawValue else {
            return nil
        }
        
        return Self(rawValue: rawValue)
    }
}

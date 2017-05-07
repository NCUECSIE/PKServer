import Foundation
import BSON

public protocol PKEnumReflectionSerializable: PKPrimitiveConvertible {
    func serialize() throws -> Primitive
    static func deserialize(`case`: String, values: [Primitive]?) -> Self?
}

public extension PKEnumReflectionSerializable {
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
    static func deserialize(from primitive: Primitive) -> Self? {
        guard let serialized = primitive as? Document else { return nil }
        
        guard let `case` = serialized["case"]?.to(String.self) else { return nil }
        
        return Self.deserialize(case: `case`, values: serialized["values"]?.toArray())
    }
    func convert<DT>(to type: DT.Type) -> DT.SupportedValue? where DT : DataType {
        fatalError()
    }
}

public extension PKEnumReflectionSerializable where Self: RawRepresentable, Self.RawValue: Primitive {
    func serialize() throws -> Primitive {
        let mirror = Mirror(reflecting: self)
        guard case .some(.enum) = mirror.displayStyle else {
            fatalError("Conforming identifier is not an enum")
        }
        
        return rawValue
    }
    static func deserialize(from primitive: Primitive) -> Self? {
        guard let rawValue = primitive as? Self.RawValue else {
            return nil
        }
        
        return Self(rawValue: rawValue)
    }
    static func deserialize(`case`: String, values: [Primitive]?) -> Self? {
        fatalError("Would not be called in a RawRepresentable Enum.")
    }
}

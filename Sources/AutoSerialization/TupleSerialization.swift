import BSON

/*
func serializeTuple<T: Primitive>(_ tuple: (T)) -> [Primitive] {
    return [tuple]
}

func serializeTuple<T: Primitive, U: Primitive>(_ tuple: (T, U)) -> [Primitive] {
    return [tuple.0, tuple.1]
}

func serializeTuple<T: Primitive, U: Primitive, R: Primitive>(_ tuple: (T, U, R)) -> [Primitive] {
    return [tuple.0, tuple.1, tuple.2]
}

func serializeTuple<T: Primitive, U: Primitive, R: Primitive, S: Primitive>(_ tuple: (T, U, R, S)) -> [Primitive] {
    return [tuple.0, tuple.1, tuple.2, tuple.3]
}

func serializeTuple<T: Primitive, U: Primitive, R: Primitive, S: Primitive, V: Primitive>(_ tuple: (T, U, R, S, V)) -> [Primitive] {
    return [tuple.0, tuple.1, tuple.2, tuple.3, tuple.4]
}
*/
 
/// 用映射 API 將 Tuple 序列化
public func serializeTuple(_ tuple: Any) -> [Primitive] {
    if let tuple = tuple as? Primitive {
        return [tuple]
    }
    
    var elements: [Primitive] = []
    
    let mirror = Mirror(reflecting: tuple)
    switch mirror.displayStyle {
    case .some(.tuple):
        for (_, value) in mirror.children {
            if case .some(.tuple) = Mirror(reflecting: value).displayStyle {
                elements.append(serializeTuple(value))
            } else if let value = value as? PKPrimitiveConvertible {
                elements.append(try! value.serialize())
            } else if let value = value as? Primitive {
                elements.append(value)
            } else {
                fatalError("Tuple includes a non-Primitive value")
            }
        }
    default:
        fatalError("Argument not a tuple")
    }
    
    return elements
}

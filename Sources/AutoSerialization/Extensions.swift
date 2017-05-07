import BSON

public extension Primitive {
    func to<T: PKPrimitiveConvertible>(_: T.Type) -> T? {
        return T.deserialize(from: self)
    }
    func to<T: Primitive>(_: T.Type) -> T? {
        return self as? T
    }
    func toDocument(requiredKeys: [String] = []) -> Document? {
        var document: Document
        if self is PKPrimitiveConvertible {
            document = Document(self as! PKPrimitiveConvertible)
        } else {
            guard let doc = self.to(Document.self) else { return nil }
            document = doc
        }
        
        let keys = document.keys
        for requiredKey in requiredKeys {
            if !keys.contains(requiredKey) { return nil }
        }
        
        return document
    }
    func toArray(count: Int = -1) -> [Primitive]? {
        guard let array = self.to(Document.self)?.arrayValue else {
            return nil
        }
        if (count == -1) {
            return array
        } else {
            return array.count == count ? array : nil
        }
    }
    func toArray<T: Primitive>(typed: T.Type, count: Int = -1) -> [T]? {
        return self.toArray(count: count) as? [T]
    }
    func toArray<T: PKPrimitiveConvertible>(typed: T.Type, count: Int = -1) -> [T]? {
        guard let array = self.toArray(count: count) else { return nil }
        var result: [T] = []
        for element in array {
            guard let r = T.deserialize(from: element) else { return nil }
            result.append(r)
        }
        return result
    }
}

public extension Document {
    init(_ convertible: PKPrimitiveConvertible) {
        self.init(data: convertible.makeBinary())
    }
}

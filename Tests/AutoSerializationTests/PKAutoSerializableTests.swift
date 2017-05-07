import XCTest
import MongoKitten
import BSON
@testable import AutoSerialization

class PKSerializableTests: XCTestCase {
    func testTupleSerialization() {
        guard let singleElementTuple = serializeTuple((5)) as? [Int] else {
            XCTFail("Serializing (5) does not return an array of integer")
            return
        }
        XCTAssertEqual([5], singleElementTuple)
        
        guard let doubleElementTuple = serializeTuple((9, 1)) as? [Int] else {
            XCTFail("Serializing (9, 1) does not return an array of integer")
            return
        }
        XCTAssertEqual([9, 1], doubleElementTuple)
        
        let multiElementTuple = serializeTuple(("a", "b", -5, 99.5, ["Happy" : "Polla"], 40))
        XCTAssertEqual(multiElementTuple.count, 6)
        XCTAssertEqual(multiElementTuple[0] as? String, "a")
        XCTAssertEqual(multiElementTuple[1] as? String, "b")
        XCTAssertEqual(multiElementTuple[2] as? Int, -5)
        XCTAssertEqual(multiElementTuple[3] as? Double, 99.5)
        XCTAssertNotNil(multiElementTuple[4] as? [String: String])
        XCTAssertEqual(multiElementTuple[4] as! [String: String], ["Happy" : "Polla"])
        XCTAssertEqual(multiElementTuple[5] as? Int, 40)
    }
    func testSimpleEnum() {
        guard let x = try? TestSimpleEnum.x.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(x as? [String: Primitive])
        XCTAssertNotNil((x as! [String: Primitive])["case"])
        XCTAssertNotNil((x as! [String: Primitive])["case"]! as? String)
        XCTAssertEqual((x as! [String: Primitive])["case"]! as! String, "x")
        
        guard let y = try? TestSimpleEnum.y.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(y as? [String: Primitive])
        XCTAssertNotNil((y as! [String: Primitive])["case"])
        XCTAssertNotNil((y as! [String: Primitive])["case"]! as? String)
        XCTAssertEqual((y as! [String: Primitive])["case"]! as! String, "y")
    }
    func testIntRawEnum() {
        guard let x = try? TestIntRawEnum.x.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(x as? Int)
        XCTAssertEqual(x as! Int, 1)
        
        guard let y = try? TestIntRawEnum.y.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(y as? Int)
        XCTAssertEqual(y as! Int, 2)
    }
    func testStringRawEnum() {
        guard let x = try? TestStringRawEnum.x.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(x as? String)
        XCTAssertEqual(x as! String, "read")
        
        guard let y = try? TestStringRawEnum.y.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(y as? String)
        XCTAssertEqual(y as! String, "write")
    }
    func testAssociatedEnum() {
        guard let x = try? TestAssociatedEnum.x(1, 2).serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(x as? [String: Primitive])
        XCTAssertNotNil((x as! [String: Primitive])["case"])
        XCTAssertNotNil((x as! [String: Primitive])["case"]! as? String)
        XCTAssertEqual((x as! [String: Primitive])["case"]! as! String, "x")
        XCTAssertNotNil((x as! [String: Primitive])["values"])
        XCTAssertNotNil((x as! [String: Primitive])["values"]! as? [Int])
        XCTAssertEqual(((x as! [String: Primitive])["values"]! as! [Int]).count, 2)
        XCTAssertEqual(((x as! [String: Primitive])["values"]! as! [Int])[0], 1)
        XCTAssertEqual(((x as! [String: Primitive])["values"]! as! [Int])[1], 2)
        
        guard let y = try? TestAssociatedEnum.y("1", 2).serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(y as? [String: Primitive])
        XCTAssertNotNil((y as! [String: Primitive])["case"])
        XCTAssertNotNil((y as! [String: Primitive])["case"]! as? String)
        XCTAssertEqual((y as! [String: Primitive])["case"]! as! String, "y")
        XCTAssertNotNil((y as! [String: Primitive])["values"])
        XCTAssertNotNil((y as! [String: Primitive])["values"]! as? [Any])
        XCTAssertEqual(((y as! [String: Primitive])["values"]! as! [Any]).count, 2)
        XCTAssertNotNil(((y as! [String: Primitive])["values"]! as! [Any])[0] as? String)
        XCTAssertEqual(((y as! [String: Primitive])["values"]! as! [Any])[0] as! String, "1")
        XCTAssertNotNil(((y as! [String: Primitive])["values"]! as! [Any])[1] as? Int)
        XCTAssertEqual(((y as! [String: Primitive])["values"]! as! [Any])[1] as! Int, 2)
    }
    func testStructSerialization() {
        guard let serialized = try? TestStruct().serialize() else {
            XCTFail("Serialization failed.")
            return
        }
        guard let result = serialized as? [String: Primitive] else {
            XCTFail("Serialization failed.")
            return
        }
        
        XCTAssertEqual(result["var1"] as? String, "a")
        XCTAssertEqual(result["var2"] as? String, "b")
        XCTAssertEqual(result["var3"] as? Int, -5)
        XCTAssertEqual(result["var4"] as? Double, 99.25)
        XCTAssertNotNil(result["var5"])
        XCTAssertNotNil(result["var5"]! as? [Int])
        XCTAssertEqual(result["var5"]! as! [Int], [1, 2, 3])
        XCTAssertNotNil(result["var6"])
        XCTAssertNotNil(result["var6"]! as? [String: Int])
        XCTAssertEqual(result["var6"]! as! [String: Int], ["A": 1, "B": 2, "C": 3])
        XCTAssertNotNil(result["var7"])
        XCTAssertNotNil(result["var7"]! as? [Primitive])
        XCTAssertEqual((result["var7"]! as! [Primitive]).count, 6)
        XCTAssertNotNil((result["var7"]! as! [Primitive])[0] as? Int)
        XCTAssertEqual((result["var7"]! as! [Primitive])[0] as! Int, 1)
        XCTAssertNotNil((result["var7"]! as! [Primitive])[1] as? String)
        XCTAssertEqual((result["var7"]! as! [Primitive])[1] as! String, "A")
        XCTAssertNotNil((result["var7"]! as! [Primitive])[2] as? [Int])
        XCTAssertEqual((result["var7"]! as! [Primitive])[2] as! [Int], [2, 3])
        XCTAssertNotNil((result["var7"]! as! [Primitive])[3] as? (Int))
        XCTAssertEqual((result["var7"]! as! [Primitive])[3] as! (Int), 1)
        XCTAssertNotNil((result["var7"]! as! [Primitive])[4] as? [String: String])
        XCTAssertEqual((result["var7"]! as! [Primitive])[4] as! [String: String], ["A": "B"])
        XCTAssertNotNil((result["var7"]! as! [Primitive])[5] as? [Int])
        XCTAssertEqual((result["var7"]! as! [Primitive])[5] as! [Int], [1, 2, 3])
        XCTAssertNotNil(result["var8"])
        XCTAssertNotNil(result["var8"]! as? [String : Any])
        XCTAssertNotNil((result["var8"]! as! [String : Any])["A"])
        XCTAssertNotNil((result["var8"]! as! [String : Any])["A"]! as? [Int])
        XCTAssertEqual((result["var8"]! as! [String : Any])["A"] as! [Int], [1, 2])
        XCTAssertNotNil((result["var8"]! as! [String : Any])["B"])
        XCTAssertNotNil((result["var8"]! as! [String : Any])["B"]! as? [String: Any])
        XCTAssertNotNil(((result["var8"]! as! [String : Any])["B"] as! [String: Any])["A"])
        XCTAssertNotNil(((result["var8"]! as! [String : Any])["B"] as! [String: Any])["A"]! as? Int)
        XCTAssertEqual(((result["var8"]! as! [String : Any])["B"] as! [String: Any])["A"]! as! Int, 1)
        XCTAssertNotNil(((result["var8"]! as! [String : Any])["B"] as! [String: Any])["B"])
        XCTAssertNotNil(((result["var8"]! as! [String : Any])["B"] as! [String: Any])["B"]! as? String)
        XCTAssertEqual(((result["var8"]! as! [String : Any])["B"] as! [String: Any])["B"]! as! String, "C")
        XCTAssertNotNil(result["var9"])
        XCTAssertNotNil(result["var9"] as? Bool)
        XCTAssertEqual(result["var9"] as! Bool, true)
        XCTAssertNotNil(result["var10"])
        XCTAssertNotNil(result["var10"]! as? [String: Primitive])
        XCTAssertNotNil((result["var10"]! as! [String: Primitive])["case"])
        XCTAssertNotNil((result["var10"]! as! [String: Primitive])["case"]! as? String)
        XCTAssertEqual((result["var10"]! as! [String: Primitive])["case"]! as! String, "y")
        XCTAssertNotNil((result["var10"]! as! [String: Primitive])["values"])
        XCTAssertNotNil((result["var10"]! as! [String: Primitive])["values"]! as? [Any])
        XCTAssertEqual(((result["var10"]! as! [String: Primitive])["values"]! as! [Any]).count, 2)
        XCTAssertNotNil(((result["var10"]! as! [String: Primitive])["values"]! as! [Any])[0] as? String)
        XCTAssertEqual(((result["var10"]! as! [String: Primitive])["values"]! as! [Any])[0] as! String, "A")
        XCTAssertNotNil(((result["var10"]! as! [String: Primitive])["values"]! as! [Any])[1] as? Int)
        XCTAssertEqual(((result["var10"]! as! [String: Primitive])["values"]! as! [Any])[1] as! Int, 1)
        
        
        let binary = serialized.makeBinary()
        let doc = Document(data: binary)
        
        XCTAssertNotNil(TestStruct.deserialize(from: doc))
    }
    
}

fileprivate struct TestStruct: PKObjectReflectionSerializable {
    var var1 = "a"
    var var2 = "b"
    var var3 = -5
    var var4 = 99.25
    var var5 = [1, 2, 3]
    var var6 = ["A": 1, "B": 2, "C": 3]
    var var7 = (1, "A", [2, 3], (1), ["A": "B"], (1, 2, 3))
    var var8 = [
        "A": [1, 2],
        "B": [ "A": 1, "B": "C" ]
        ] as [String : Primitive]
    var var9 = true
    var var10 = TestAssociatedEnum.y("A", 1)
    
    static func deserialize(from primitive: Primitive) -> TestStruct? {
        guard let serialized = primitive.to(Document.self) else { return nil }
        guard let v1 = serialized["var1"]?.to(String.self) else { return nil }
        guard let v2 = serialized["var2"]?.to(String.self) else { return nil }
        guard let v3 = serialized["var3"]?.to(Int.self) else { return nil }
        guard let v4 = serialized["var4"]?.to(Double.self) else { return nil }
        guard let v5 = serialized["var5"]?.toArray(typed: Int.self) else { return nil }
        guard let v6 = serialized["var6"]?.to(Document.self)?.dictionaryValue as? [String: Int] else { return nil }
        guard let _v7 = serialized["var7"]?.toArray(count: 6) else { return nil }
        guard let v8 = serialized["var8"]?.to(Document.self)?.dictionaryValue else { return nil }
        guard let v9 = serialized["var9"]?.to(Bool.self) else { return nil }
        guard let v10 = serialized["var10"]?.to(TestAssociatedEnum.self) else { return nil }
        
        guard let x1 = _v7[0].to(Int.self),
              let x2 = _v7[1].to(String.self),
              let x3 = _v7[2].toArray(typed: Int.self),
              let x4 = _v7[3].to(Int.self),
              let x5 = _v7[4].to(Document.self)?.dictionaryValue as? [String: String],
              let x6 = _v7[5].toArray(typed: Int.self, count: 3)?.tuple(Int.self, Int.self, Int.self) else {
            return nil
        }
        
        var r = TestStruct()
        r.var1 = v1
        r.var2 = v2
        r.var3 = v3
        r.var4 = v4
        r.var5 = v5
        r.var6 = v6
        r.var7 = (x1, x2, x3, x4, x5, x6)
        r.var8 = v8
        r.var9 = v9
        r.var10 = v10
        
        return r
    }
}

fileprivate enum TestSimpleEnum: PKEnumReflectionSerializable {
    case x
    case y
    static func deserialize(case: String, values: [Primitive]?) -> TestSimpleEnum? {
        switch `case` {
        case "x":
            return .x
        case "y":
            return .y
        default: return nil
        }
    }
}

fileprivate enum TestIntRawEnum: Int, PKEnumReflectionSerializable {
    case x = 1
    case y = 2
}

fileprivate enum TestStringRawEnum: String, PKEnumReflectionSerializable {
    case x = "read"
    case y = "write"
}

fileprivate enum TestAssociatedEnum: PKEnumReflectionSerializable {
    case x(Int, Int)
    case y(String, Int)
    static func deserialize(case: String, values: [Primitive]?) -> TestAssociatedEnum? {
        guard let values = values else { return nil }
        guard values.count == 2 else { return nil }
        guard let _1 = values[1].to(Int.self) else { return nil }
        
        switch `case` {
        case "x":
            guard let _0 = values[0].to(Int.self) else { return nil }
            return .x(_0, _1)
        case "y":
            guard let _0 = values[0].to(String.self) else { return nil }
            return .y(_0, _1)
        default: return nil
        }
    }
}

extension Array {
    func tuple<A, B>(_: A.Type, _: B.Type) -> (A, B)? {
        guard self.count == 2, let _0 = self[0] as? A, let _1 = self[1] as? B else {
            return nil
        }
        return (_0, _1)
    }
    func tuple<A, B, C>(_: A.Type, _: B.Type, _: C.Type) -> (A, B, C)? {
        guard self.count == 3, let _0 = self[0] as? A, let _1 = self[1] as? B, let _2 = self[2] as? C else {
            return nil
        }
        return (_0, _1, _2)
    }
    func tuple<A, B, C, D>(_: A.Type, _: B.Type, _: C.Type, _: D.Type) -> (A, B, C, D)? {
        guard self.count == 3, let _0 = self[0] as? A, let _1 = self[1] as? B, let _2 = self[2] as? C,
            let _3 = self[3] as? D else {
            return nil
        }
        return (_0, _1, _2, _3)
    }
    func tuple<A, B, C, D, E>(_: A.Type, _: B.Type, _: C.Type, _: D.Type, _: E.Type) -> (A, B, C, D, E)? {
        guard self.count == 3, let _0 = self[0] as? A, let _1 = self[1] as? B, let _2 = self[2] as? C,
            let _3 = self[3] as? D, let _4 = self[4] as? E else {
                return nil
        }
        return (_0, _1, _2, _3, _4)
    }
    func tuple<A, B, C, D, E, F>(_: A.Type, _: B.Type, _: C.Type, _: D.Type, _: E.Type, _: F.Type) -> (A, B, C, D, E, F)? {
        guard self.count == 3, let _0 = self[0] as? A, let _1 = self[1] as? B, let _2 = self[2] as? C,
            let _3 = self[3] as? D, let _4 = self[4] as? E, let _5 = self[5] as? F else {
                return nil
        }
        return (_0, _1, _2, _3, _4, _5)
    }
}

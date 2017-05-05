import XCTest
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
        XCTAssertNotNil(x as? [String: Primitive])
        XCTAssertNotNil((x as! [String: Primitive])["case"])
        XCTAssertNotNil((x as! [String: Primitive])["case"]! as? Int)
        XCTAssertEqual((x as! [String: Primitive])["case"]! as! Int, 1)
        
        guard let y = try? TestIntRawEnum.y.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(y as? [String: Primitive])
        XCTAssertNotNil((y as! [String: Primitive])["case"])
        XCTAssertNotNil((y as! [String: Primitive])["case"]! as? Int)
        XCTAssertEqual((y as! [String: Primitive])["case"]! as! Int, 2)
    }
    func testStringRawEnum() {
        guard let x = try? TestStringRawEnum.x.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(x as? [String: Primitive])
        XCTAssertNotNil((x as! [String: Primitive])["case"])
        XCTAssertNotNil((x as! [String: Primitive])["case"]! as? String)
        XCTAssertEqual((x as! [String: Primitive])["case"]! as! String, "read")
        
        guard let y = try? TestStringRawEnum.y.serialize() else {
            XCTFail()
            return
        }
        XCTAssertNotNil(y as? [String: Primitive])
        XCTAssertNotNil((y as! [String: Primitive])["case"])
        XCTAssertNotNil((y as! [String: Primitive])["case"]! as? String)
        XCTAssertEqual((y as! [String: Primitive])["case"]! as! String, "write")
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
        
        let s = TestStruct.deserialize(doc: doc)
        
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
        ] as [String : Any]
    var var9 = true
    var var10 = TestAssociatedEnum.y("A", 1)
    
    static func deserialize(doc: Primitive) -> TestStruct? {
        guard let serialized = doc as? Document else { return nil }
        guard let v1 = serialized["var1"] as? String else { return nil }
        guard let v2 = serialized["var2"] as? String else { return nil }
        guard let v3 = serialized["var3"] as? Int else { return nil }
        guard let v4 = serialized["var4"] as? Double else { return nil }
        guard let _v5 = serialized["var5"] as? Document else { return nil }
        guard let _v6 = serialized["var6"] as? Document else { return nil }
        guard let _v7 = serialized["var7"] as? Document else { return nil }
        guard let _v8 = serialized["var8"] as? Document else { return nil }
        guard let v9 = serialized["var9"] as? Bool else { return nil }
        guard let v10 = serialized["var10"] else { return nil }
        
        guard let v5 = _v5.arrayValue as? [Int] else { return nil }
        guard let v6 = _v6.dictionaryValue as? [String: Int] else { return nil }
        let v7 = _v7.arrayValue as [Any]
        let v8 = _v8.dictionaryValue as [String: Any]
        guard let x1 = v7[0] as? Int, let x2 = v7[1] as? String, let _x3 = v7[2] as? Document, let x3 = _x3.arrayValue as? [Int],
            let x4 = v7[3] as? (Int), let _x5 = v7[4] as? Document, let x5 = _x5.dictionaryValue as? [String: String],
            let __x6 = v7[5] as? Document, let _x6 = __x6.arrayValue as? [Int], _x6.count == 3 else {
            return nil
        }
        let x6 = (_x6[0], _x6[1], _x6[2])
        
        guard v7.count == 6 else { return nil }
        let __v7 = (x1, x2, x3, x4, x5, x6)
        guard let __v10 = TestAssociatedEnum.deserialize(doc: v10) else { return nil }
        
        var r = TestStruct()
        r.var1 = v1
        r.var2 = v2
        r.var3 = v3
        r.var4 = v4
        r.var5 = v5
        r.var6 = v6
        r.var7 = __v7
        r.var8 = v8
        r.var9 = v9
        r.var10 = __v10
        
        return r
    }
}

fileprivate enum TestSimpleEnum: PKEnumReflectionSerializable {
    case x
    case y
    
    static func deserialize(doc: Primitive) -> TestSimpleEnum? {
        guard let serialized = doc as? [String: Primitive] else { return nil }
        guard let `case` = serialized["case"] as? String else { return nil }
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
    
    static func deserialize(doc: Primitive) -> TestAssociatedEnum? {
        guard let serialized = doc as? Document else { return nil }
        
        guard let `case` = serialized["case"] as? String else { return nil }
        guard let _values = serialized["values"] as? Document else { return nil }
        let values = _values.arrayValue as [Any]
        if values.count != 2 { return nil }
        guard let _1 = values[1] as? Int else { return nil }
        
        switch `case` {
        case "x":
            guard let _0 = values[0] as? Int else { return nil }
            return .x(_0, _1)
        case "y":
            guard let _0 = values[0] as? String else { return nil }
            return .y(_0, _1)
        default: return nil
        }
    }
}

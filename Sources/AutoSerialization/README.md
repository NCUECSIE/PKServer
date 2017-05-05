# PKAutoSerialization

The core of the serialization is `PKPrimitiveConvertible`, which is a protocol that bridges your custom type into `Primitive`. we provide two generic implementation as protocols `PKObjectReflectionSerializable` and `PKEnumReflectionSerializable`. 

> It should be noted that `PKObjectReflectionSerializable` does not serialize members with `__` prefix.

When you call `serialize()`, you will get a serialized view of the value, that is compatible with JSON. 

Since tuples are not extensible, you must call `serialize()` yourself, or at least put it in a custom data type that supports `PKPrimitiveConvertible` so we all `serialize()` on the tuple for you.

To support deserialization, you must deserialize member tuples yourselves in your `deserialize()` function. You must define `deserialize()` function for structures and enums that are not `RawRepresentable`. 

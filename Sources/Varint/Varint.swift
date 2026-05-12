import Bytes

/// LEB128 + ZigZag-LEB128 varint codec namespace.
public enum Varint {
    /// Maximum encoded byte count for a `UInt32` (or `Int32` via ZigZag).
    public static let maxBytes32 = 5

    /// Maximum encoded byte count for a `UInt64` (or `Int64` via ZigZag).
    public static let maxBytes64 = 10
}

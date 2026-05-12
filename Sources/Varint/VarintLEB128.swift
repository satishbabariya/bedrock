import Bytes

extension Varint {

    /// Encode an unsigned 64-bit LEB128 varint into `out`. Returns the byte
    /// count appended (1–10).
    @discardableResult
    public static func encode(_ value: UInt64, into out: inout BytesMut) -> Int {
        var v = value
        var count = 0
        while v >= 0x80 {
            out.putUInt8(UInt8(v & 0x7F) | 0x80)
            v >>= 7
            count += 1
        }
        out.putUInt8(UInt8(v))
        return count + 1
    }

    /// Encode an unsigned 32-bit LEB128 varint into `out`. Returns 1–5.
    @discardableResult
    public static func encode(_ value: UInt32, into out: inout BytesMut) -> Int {
        var v = value
        var count = 0
        while v >= 0x80 {
            out.putUInt8(UInt8(v & 0x7F) | 0x80)
            v >>= 7
            count += 1
        }
        out.putUInt8(UInt8(v))
        return count + 1
    }
}

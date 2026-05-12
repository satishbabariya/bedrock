import Bytes

extension Varint {

    // ─── ZigZag wrappers (internal) ──────────────────────────────────────

    @inline(__always)
    internal static func zigzagEncode(_ n: Int32) -> UInt32 {
        UInt32(bitPattern: (n << 1) ^ (n >> 31))
    }

    @inline(__always)
    internal static func zigzagEncode(_ n: Int64) -> UInt64 {
        UInt64(bitPattern: (n << 1) ^ (n >> 63))
    }

    @inline(__always)
    internal static func zigzagDecode(_ u: UInt32) -> Int32 {
        Int32(bitPattern: (u >> 1)) ^ -Int32(bitPattern: u & 1)
    }

    @inline(__always)
    internal static func zigzagDecode(_ u: UInt64) -> Int64 {
        Int64(bitPattern: (u >> 1)) ^ -Int64(bitPattern: u & 1)
    }

    // ─── Signed encode (delegates to unsigned) ──────────────────────────

    /// Encode a signed 32-bit ZigZag-LEB128 varint into `out`. Returns 1–5.
    @discardableResult
    public static func encode(_ value: Int32, into out: inout BytesMut) -> Int {
        encode(zigzagEncode(value), into: &out)
    }

    /// Encode a signed 64-bit ZigZag-LEB128 varint into `out`. Returns 1–10.
    @discardableResult
    public static func encode(_ value: Int64, into out: inout BytesMut) -> Int {
        encode(zigzagEncode(value), into: &out)
    }

    // ─── Signed one-shot encode ─────────────────────────────────────────

    public static func encoded(_ value: Int32) -> Bytes {
        var b = BytesMut(capacity: maxBytes32)
        encode(value, into: &b)
        return b.freeze()
    }

    public static func encoded(_ value: Int64) -> Bytes {
        var b = BytesMut(capacity: maxBytes64)
        encode(value, into: &b)
        return b.freeze()
    }

    // ─── Signed decode ──────────────────────────────────────────────────

    /// Decode a signed 32-bit ZigZag-LEB128 varint.
    public static func decodeInt32(from reader: inout BytesReader) throws -> Int32 {
        zigzagDecode(try decodeUInt32(from: &reader))
    }

    /// Decode a signed 64-bit ZigZag-LEB128 varint.
    public static func decodeInt64(from reader: inout BytesReader) throws -> Int64 {
        zigzagDecode(try decodeUInt64(from: &reader))
    }

    // ─── Signed one-shot decode ─────────────────────────────────────────

    public static func decodeInt32(from bytes: Bytes) throws -> (value: Int32, consumed: Int) {
        var r = BytesReader(bytes)
        let v = try decodeInt32(from: &r)
        return (v, r.consumed)
    }

    public static func decodeInt64(from bytes: Bytes) throws -> (value: Int64, consumed: Int) {
        var r = BytesReader(bytes)
        let v = try decodeInt64(from: &r)
        return (v, r.consumed)
    }
}

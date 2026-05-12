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

    /// Decode an unsigned 64-bit LEB128 varint. Throws `.truncated` if input
    /// ends mid-varint, `.overflow` if the encoded form exceeds 10 bytes or
    /// the final byte's payload would overflow `UInt64`.
    public static func decodeUInt64(from reader: inout BytesReader) throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var byteCount = 0
        while byteCount < maxBytes64 {
            guard let byte = reader.readUInt8() else { throw VarintError.truncated }
            byteCount += 1
            let payload = UInt64(byte & 0x7F)
            if byteCount == maxBytes64 && payload > 1 {
                throw VarintError.overflow
            }
            result |= payload << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw VarintError.overflow
    }

    /// Decode an unsigned 32-bit LEB128 varint. Bounded at 5 bytes; the
    /// 5th byte's payload must fit in 4 bits.
    public static func decodeUInt32(from reader: inout BytesReader) throws -> UInt32 {
        var result: UInt32 = 0
        var shift: UInt32 = 0
        var byteCount = 0
        while byteCount < maxBytes32 {
            guard let byte = reader.readUInt8() else { throw VarintError.truncated }
            byteCount += 1
            let payload = UInt32(byte & 0x7F)
            if byteCount == maxBytes32 && payload > 0x0F {
                throw VarintError.overflow
            }
            result |= payload << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw VarintError.overflow
    }
}

extension Varint {

    /// One-shot encode: returns the varint bytes as a fresh `Bytes` value.
    public static func encoded(_ value: UInt64) -> Bytes {
        var b = BytesMut(capacity: maxBytes64)
        encode(value, into: &b)
        return b.freeze()
    }

    /// One-shot encode for UInt32. Result is 1–5 bytes.
    public static func encoded(_ value: UInt32) -> Bytes {
        var b = BytesMut(capacity: maxBytes32)
        encode(value, into: &b)
        return b.freeze()
    }

    /// One-shot decode: returns the value and the number of bytes consumed.
    public static func decodeUInt64(from bytes: Bytes) throws -> (value: UInt64, consumed: Int) {
        var r = BytesReader(bytes)
        let v = try decodeUInt64(from: &r)
        return (v, r.consumed)
    }

    /// One-shot decode for UInt32.
    public static func decodeUInt32(from bytes: Bytes) throws -> (value: UInt32, consumed: Int) {
        var r = BytesReader(bytes)
        let v = try decodeUInt32(from: &r)
        return (v, r.consumed)
    }
}

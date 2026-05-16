import Bytes

extension PercentEncoding {

    /// Shared internal byte-level decoder. Appends decoded bytes into `out`.
    private static func decodeBytes(
        _ src: [UInt8],
        plusToSpace: Bool,
        into out: inout BytesMut
    ) throws {
        var i = 0
        while i < src.count {
            let b = src[i]
            if b == 0x25 {                          // '%'
                guard i + 2 < src.count else {
                    throw PercentEncodingError.malformedEscape(offset: i)
                }
                let hi = decodeNibble(src[i + 1])
                let lo = decodeNibble(src[i + 2])
                if hi == 0xFF || lo == 0xFF {
                    throw PercentEncodingError.malformedEscape(offset: i)
                }
                out.putUInt8((hi << 4) | lo)
                i += 3
            } else if b == 0x2B && plusToSpace {    // '+' in form mode
                out.putUInt8(0x20)
                i += 1
            } else {
                out.putUInt8(b)
                i += 1
            }
        }
    }

    /// Decode a percent-encoded string. `+` is treated as a literal `+`.
    /// Throws `.malformedEscape(offset:)` on truncated or non-hex `%XX`.
    public static func decode(_ string: String) throws -> Bytes {
        var out = BytesMut(capacity: string.utf8.count)
        try decodeBytes(Array(string.utf8), plusToSpace: false, into: &out)
        return out.freeze()
    }

    /// Decode percent-encoded ASCII bytes.
    public static func decode(_ bytes: Bytes) throws -> Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(bytes.count)
        bytes.withUnsafeBytes { src in
            arr.append(contentsOf: src)
        }
        var out = BytesMut(capacity: arr.count)
        try decodeBytes(arr, plusToSpace: false, into: &out)
        return out.freeze()
    }

    /// Stream-decode `string` into `out`. Returns the byte count appended.
    @discardableResult
    public static func decode(_ string: String, into out: inout BytesMut) throws -> Int {
        let before = out.count
        try decodeBytes(Array(string.utf8), plusToSpace: false, into: &out)
        return out.count - before
    }

    /// Decode `application/x-www-form-urlencoded`: same as `decode` but
    /// maps `+` to ASCII space (0x20).
    public static func decodeForm(_ string: String) throws -> Bytes {
        var out = BytesMut(capacity: string.utf8.count)
        try decodeBytes(Array(string.utf8), plusToSpace: true, into: &out)
        return out.freeze()
    }

    /// Stream-decode form into `out`. Returns the byte count appended.
    @discardableResult
    public static func decodeForm(_ string: String, into out: inout BytesMut) throws -> Int {
        let before = out.count
        try decodeBytes(Array(string.utf8), plusToSpace: true, into: &out)
        return out.count - before
    }
}

import Bytes

/// Hex (base-16) codec namespace.
public enum Hex {
    /// Encoding case for hex output.
    public enum Case: Sendable {
        case lower    // "deadbeef"
        case upper    // "DEADBEEF"
    }
}

extension Hex {
    /// Hex-encode `bytes` to a String. Default case is lowercase.
    public static func encode(_ bytes: Bytes, case: Case = .lower) -> String {
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        bytes.withUnsafeBytes { src in
            for byte in src {
                out.append(alphabet[Int(byte >> 4)])
                out.append(alphabet[Int(byte & 0x0F)])
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Sequence overload — useful for `[UInt8]`, `Array(...)`, etc.
    public static func encode<S: Sequence>(_ bytes: S, case: Case = .lower) -> String
    where S.Element == UInt8 {
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        var out: [UInt8] = []
        out.reserveCapacity(bytes.underestimatedCount * 2)
        for byte in bytes {
            out.append(alphabet[Int(byte >> 4)])
            out.append(alphabet[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Stream-encode into a `BytesMut`. Appends 2 ASCII bytes per input byte.
    public static func encode(_ bytes: Bytes, into out: inout BytesMut, case: Case = .lower) {
        guard !bytes.isEmpty else { return }
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        out.reserveCapacity(out.count + bytes.count * 2)
        bytes.withUnsafeBytes { src in
            for byte in src {
                out.putUInt8(alphabet[Int(byte >> 4)])
                out.putUInt8(alphabet[Int(byte & 0x0F)])
            }
        }
    }
}

extension Hex {
    /// Decode a hex string. Case-insensitive. Throws on odd length or
    /// non-hex characters.
    public static func decode(_ s: String) throws -> Bytes {
        var utf8: [UInt8] = []
        utf8.reserveCapacity(s.utf8.count)
        utf8.append(contentsOf: s.utf8)
        return try decodeBytes(utf8)
    }

    /// Decode hex bytes (ASCII). Same semantics as the String overload.
    public static func decode(_ bytes: Bytes) throws -> Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(bytes.count)
        bytes.withUnsafeBytes { src in
            arr.append(contentsOf: src)
        }
        return try decodeBytes(arr)
    }

    /// Stream-decode into a `BytesMut`. Returns the number of decoded bytes
    /// appended.
    @discardableResult
    public static func decode(_ s: String, into out: inout BytesMut) throws -> Int {
        let decoded = try decode(s)
        out.putBytes(decoded)
        return decoded.count
    }

    private static func decodeBytes(_ src: [UInt8]) throws -> Bytes {
        guard src.count.isMultiple(of: 2) else {
            throw HexError.oddLength(src.count)
        }
        var out = BytesMut(capacity: src.count / 2)
        var i = 0
        while i < src.count {
            let hi = hexDecodeTable[Int(src[i])]
            if hi == 0xFF {
                throw HexError.invalidCharacter(offset: i, byte: src[i])
            }
            let lo = hexDecodeTable[Int(src[i + 1])]
            if lo == 0xFF {
                throw HexError.invalidCharacter(offset: i + 1, byte: src[i + 1])
            }
            out.putUInt8((hi << 4) | lo)
            i += 2
        }
        return out.freeze()
    }
}

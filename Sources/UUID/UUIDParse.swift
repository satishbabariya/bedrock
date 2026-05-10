extension UUID {

    /// Permissive parse: accepts canonical, braces, urn:uuid: prefix,
    /// and 32-char hyphenless. Hex case-insensitive. Throws on any
    /// other shape.
    public init(parsing string: String) throws {
        var s = string

        // Strip URN prefix (case-insensitive).
        if s.lowercased().hasPrefix("urn:uuid:") {
            s = String(s.dropFirst("urn:uuid:".count))
        }
        // Strip braces.
        if s.hasPrefix("{"), s.hasSuffix("}") {
            s = String(s.dropFirst().dropLast())
        }

        let utf8 = Array(s.utf8)
        let bytes: SIMD16<UInt8>
        switch utf8.count {
        case 36: bytes = try Self.parseCanonical(utf8)
        case 32: bytes = try Self.parseHyphenless(utf8)
        default: throw UUIDError.invalidFormat
        }
        self.init(storage: bytes)
    }

    private static func parseCanonical(_ utf8: [UInt8]) throws -> SIMD16<UInt8> {
        guard utf8[8] == 0x2D && utf8[13] == 0x2D
           && utf8[18] == 0x2D && utf8[23] == 0x2D
        else { throw UUIDError.invalidFormat }
        var out = SIMD16<UInt8>()
        var byteIdx = 0
        var i = 0
        while i < 36 {
            if utf8[i] == 0x2D { i += 1; continue }
            let hi = Self.decodeNibble(utf8[i])
            let lo = Self.decodeNibble(utf8[i + 1])
            if hi == 0xFF { throw UUIDError.invalidHexCharacter(offset: i, byte: utf8[i]) }
            if lo == 0xFF { throw UUIDError.invalidHexCharacter(offset: i + 1, byte: utf8[i + 1]) }
            out[byteIdx] = (hi << 4) | lo
            byteIdx += 1
            i += 2
        }
        return out
    }

    private static func parseHyphenless(_ utf8: [UInt8]) throws -> SIMD16<UInt8> {
        var out = SIMD16<UInt8>()
        var byteIdx = 0
        var i = 0
        while i < 32 {
            let hi = Self.decodeNibble(utf8[i])
            let lo = Self.decodeNibble(utf8[i + 1])
            if hi == 0xFF { throw UUIDError.invalidHexCharacter(offset: i, byte: utf8[i]) }
            if lo == 0xFF { throw UUIDError.invalidHexCharacter(offset: i + 1, byte: utf8[i + 1]) }
            out[byteIdx] = (hi << 4) | lo
            byteIdx += 1
            i += 2
        }
        return out
    }
}

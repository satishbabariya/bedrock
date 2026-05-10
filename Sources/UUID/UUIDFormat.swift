extension UUID: CustomStringConvertible {

    /// Canonical lowercase: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.
    public var description: String { formatted(.canonicalLower) }

    /// Output format options.
    public enum Format: Sendable {
        case canonicalLower    // 550e8400-e29b-41d4-a716-446655440000
        case canonicalUpper    // 550E8400-E29B-41D4-A716-446655440000
        case hyphenless        // 550e8400e29b41d4a716446655440000
        case braced            // {550e8400-e29b-41d4-a716-446655440000}
        case urn               // urn:uuid:550e8400-e29b-41d4-a716-446655440000
    }

    public func formatted(_ format: Format) -> String {
        let alphabet: [UInt8] = (format == .canonicalUpper)
            ? Array("0123456789ABCDEF".utf8)
            : Array("0123456789abcdef".utf8)
        var out: [UInt8] = []
        out.reserveCapacity(45)  // longest: urn:uuid:... = 9 + 36 = 45
        if format == .urn {
            out.append(contentsOf: Array("urn:uuid:".utf8))
        }
        if format == .braced { out.append(0x7B) }
        let needsHyphens = (format != .hyphenless)
        for i in 0..<16 {
            let b = storage[i]
            out.append(alphabet[Int(b >> 4)])
            out.append(alphabet[Int(b & 0x0F)])
            if needsHyphens && (i == 3 || i == 5 || i == 7 || i == 9) {
                out.append(0x2D)
            }
        }
        if format == .braced { out.append(0x7D) }
        return String(decoding: out, as: UTF8.self)
    }

    /// Internal nibble decoder shared with the permissive parser. Returns
    /// 0xFF for non-hex input. Duplicated in spirit from the Hex module —
    /// see spec §6.1 for the rationale (no peer Layer 1 imports).
    @inline(__always)
    static func decodeNibble(_ b: UInt8) -> UInt8 {
        switch b {
        case 0x30...0x39: return b - 0x30
        case 0x41...0x46: return b - 0x41 + 10
        case 0x61...0x66: return b - 0x61 + 10
        default:          return 0xFF
        }
    }
}

/// Standard Base64 alphabet (RFC 4648 §4). Indexed by 0...63.
@usableFromInline
internal let base64StandardAlphabet: [UInt8] = Array(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

/// URL-safe Base64 alphabet (RFC 4648 §5). Indexed by 0...63.
@usableFromInline
internal let base64UrlSafeAlphabet: [UInt8] = Array(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)

/// ASCII '=' padding character.
@usableFromInline
internal let base64Pad: UInt8 = 0x3D

/// Sentinel values in the decode table.
@usableFromInline internal let base64Whitespace: UInt8 = 0xFE
@usableFromInline internal let base64PadSentinel: UInt8 = 0xFD
@usableFromInline internal let base64Invalid: UInt8 = 0xFF

/// 256-entry decode table mapping ASCII byte → 6-bit value (0...63),
/// `base64Whitespace`, `base64PadSentinel`, or `base64Invalid`.
/// Both standard and url-safe alphabet characters resolve to their value;
/// the auto-detect pass below validates that they don't appear in the
/// same input.
@usableFromInline
internal let base64DecodeTable: [UInt8] = (0..<256).map { i in
    let b = UInt8(i)
    switch b {
    case 0x41...0x5A: return b - 0x41           // A-Z → 0...25
    case 0x61...0x7A: return b - 0x61 + 26      // a-z → 26...51
    case 0x30...0x39: return b - 0x30 + 52      // 0-9 → 52...61
    case 0x2B:        return 62                 // '+'
    case 0x2F:        return 63                 // '/'
    case 0x2D:        return 62                 // '-' (url-safe)
    case 0x5F:        return 63                 // '_' (url-safe)
    case 0x3D:        return base64PadSentinel  // '='
    case 0x09, 0x0A, 0x0D, 0x20: return base64Whitespace
    default:          return base64Invalid
    }
}

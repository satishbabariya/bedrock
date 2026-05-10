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

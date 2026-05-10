import Bytes

/// Branch-free Base64 decoder. Accepts both standard and url-safe alphabets.
/// Rejects whitespace and any non-alphabet byte. Runtime is a function of
/// input length only — never of which byte was invalid.
///
/// Algorithm: classify each byte into a 6-bit value or "invalid" using
/// arithmetic comparisons (no data-dependent branches). Accumulate a
/// running invalid-mask across the whole input. After processing all
/// bytes, a single check on the mask determines whether to throw.
@usableFromInline
internal func base64DecodeConstantTime(_ src: [UInt8]) throws -> Bytes {
    // Strip up to 2 trailing '=' bytes for padding handling. The strip
    // count itself is data-dependent on the very last bytes, but those
    // bytes are public (length is public). We treat padding handling as
    // public information.
    var len = src.count
    var paddingCount = 0
    if len >= 1, src[len - 1] == 0x3D {
        paddingCount += 1
        len -= 1
    }
    if len >= 1, src[len - 1] == 0x3D {
        paddingCount += 1
        len -= 1
    }

    var invalidMask: UInt32 = 0
    var quantum: UInt32 = 0
    var sextets = 0
    var out = BytesMut(capacity: (len / 4) * 3 + 3)

    for i in 0..<len {
        let b = UInt32(src[i])
        let value = classifyByte(b, invalidMask: &invalidMask)

        quantum = (quantum << 6) | value
        sextets += 1

        if sextets == 4 {
            out.putUInt8(UInt8((quantum >> 16) & 0xFF))
            out.putUInt8(UInt8((quantum >>  8) & 0xFF))
            out.putUInt8(UInt8(quantum & 0xFF))
            quantum = 0
            sextets = 0
        }
    }

    // Tail
    switch sextets {
    case 0: break
    case 1:
        // Invalid quantum length — but we still emit nothing and mark invalid.
        invalidMask |= 1
    case 2:
        quantum <<= 12
        out.putUInt8(UInt8((quantum >> 16) & 0xFF))
    case 3:
        quantum <<= 6
        out.putUInt8(UInt8((quantum >> 16) & 0xFF))
        out.putUInt8(UInt8((quantum >>  8) & 0xFF))
    default: break
    }

    if invalidMask != 0 {
        // The output BytesMut is dropped on throw; ARC reclaims storage.
        // True secure-zeroize requires libsodium-style memset_s, which
        // doesn't land until Layer 12 crypto.
        throw Base64Error.constantTimeRejected
    }

    return out.freeze()
}

/// Classify an ASCII byte into a 6-bit value. Updates `invalidMask`
/// (OR-merging) when the byte is outside both alphabets. All ops are
/// branch-free arithmetic on UInt32.
@inline(__always)
private func classifyByte(_ b: UInt32, invalidMask: inout UInt32) -> UInt32 {
    // Range checks return 0xFFFFFFFF if in range, 0 otherwise.
    let isUpper  = inRange(b, lo: 0x41, hi: 0x5A)   // A-Z → 0-25
    let isLower  = inRange(b, lo: 0x61, hi: 0x7A)   // a-z → 26-51
    let isDigit  = inRange(b, lo: 0x30, hi: 0x39)   // 0-9 → 52-61
    let isPlus   = eq(b, 0x2B)                       // '+' → 62
    let isSlash  = eq(b, 0x2F)                       // '/' → 63
    let isMinus  = eq(b, 0x2D)                       // '-' → 62 (url-safe)
    let isUnder  = eq(b, 0x5F)                       // '_' → 63 (url-safe)

    let valUpper = (b &- 0x41) & isUpper
    let valLower = ((b &- 0x61) &+ 26) & isLower
    let valDigit = ((b &- 0x30) &+ 52) & isDigit
    let valPlus  = 62 & isPlus
    let valSlash = 63 & isSlash
    let valMinus = 62 & isMinus
    let valUnder = 63 & isUnder

    let value = valUpper | valLower | valDigit | valPlus | valSlash | valMinus | valUnder

    // OR all the "is-valid" masks; if none matched, the result is 0,
    // meaning the byte was not in any alphabet.
    let validMask = isUpper | isLower | isDigit | isPlus | isSlash | isMinus | isUnder
    invalidMask |= ~validMask

    return value
}

/// Returns 0xFFFFFFFF if `b` is in [lo, hi], else 0. Branch-free.
@inline(__always)
private func inRange(_ b: UInt32, lo: UInt32, hi: UInt32) -> UInt32 {
    let geLo = ge(b, lo)
    let leHi = ge(hi, b)
    return geLo & leHi
}

/// Returns 0xFFFFFFFF if a >= b, else 0. Branch-free.
@inline(__always)
private func ge(_ a: UInt32, _ b: UInt32) -> UInt32 {
    let diff = b &- a &- 1
    let bit = (diff >> 31) & 1
    return UInt32(0) &- bit
}

/// Returns 0xFFFFFFFF if a == b, else 0. Branch-free.
@inline(__always)
private func eq(_ a: UInt32, _ b: UInt32) -> UInt32 {
    let x = a ^ b
    // nz = 1 if x != 0 (a != b), else 0
    let nz = (x | (UInt32(0) &- x)) >> 31
    // Want: nz==0 → 0xFFFFFFFF, nz==1 → 0
    // 1 &- nz: nz==0 → 1, nz==1 → 0
    // 0 &- (1 &- nz): nz==0 → 0xFFFFFFFF (wrap), nz==1 → 0
    return UInt32(0) &- (1 &- nz)
}

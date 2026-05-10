import Bytes

extension UUID {

    /// Random v4 UUID using `SystemRandomNumberGenerator`.
    public static func v4() -> UUID {
        var rng = SystemRandomNumberGenerator()
        return v4(using: &rng)
    }

    /// Random v4 UUID using a caller-provided RNG.
    public static func v4<R: RandomNumberGenerator>(using rng: inout R) -> UUID {
        var s = SIMD16<UInt8>()
        let lo: UInt64 = rng.next()
        let hi: UInt64 = rng.next()
        withUnsafeMutableBytes(of: &s) { dst in
            dst.storeBytes(of: lo, toByteOffset: 0, as: UInt64.self)
            dst.storeBytes(of: hi, toByteOffset: 8, as: UInt64.self)
        }
        s[6] = (s[6] & 0x0F) | 0x40    // version 4 = 0100xxxx
        s[8] = (s[8] & 0x3F) | 0x80    // variant 10x
        return UUID(storage: s)
    }
}

extension UUID {

    /// Time-sortable v7 UUID: 48-bit Unix milliseconds + 74 random bits
    /// (RFC 9562 §5.7). Uses the wall-clock shim and `SystemRandomNumberGenerator`.
    public static func v7() -> UUID {
        var rng = SystemRandomNumberGenerator()
        return v7(unixMillisecondsSince1970: unixWallClockMilliseconds(), using: &rng)
    }

    /// v7 with caller-provided clock and RNG.
    public static func v7<R: RandomNumberGenerator>(
        unixMillisecondsSince1970: Int64,
        using rng: inout R
    ) -> UUID {
        let ms = UInt64(bitPattern: Int64(unixMillisecondsSince1970)) & 0x0000_FFFF_FFFF_FFFF
        var s = SIMD16<UInt8>()
        s[0] = UInt8((ms >> 40) & 0xFF)
        s[1] = UInt8((ms >> 32) & 0xFF)
        s[2] = UInt8((ms >> 24) & 0xFF)
        s[3] = UInt8((ms >> 16) & 0xFF)
        s[4] = UInt8((ms >>  8) & 0xFF)
        s[5] = UInt8(ms & 0xFF)
        let r0: UInt64 = rng.next()
        let r1: UInt64 = rng.next()
        s[6]  = UInt8((r0 >> 56) & 0xFF)
        s[7]  = UInt8((r0 >> 48) & 0xFF)
        s[8]  = UInt8((r0 >> 40) & 0xFF)
        s[9]  = UInt8((r0 >> 32) & 0xFF)
        s[10] = UInt8((r0 >> 24) & 0xFF)
        s[11] = UInt8((r0 >> 16) & 0xFF)
        s[12] = UInt8((r1 >> 56) & 0xFF)
        s[13] = UInt8((r1 >> 48) & 0xFF)
        s[14] = UInt8((r1 >> 40) & 0xFF)
        s[15] = UInt8((r1 >> 32) & 0xFF)
        s[6] = (s[6] & 0x0F) | 0x70    // version 7 = 0111xxxx
        s[8] = (s[8] & 0x3F) | 0x80    // variant 10x
        return UUID(storage: s)
    }
}

extension UUID {

    /// Custom v8 UUID. The provided 16 bytes are stored verbatim except
    /// for the version field (byte 6 high nibble = 8) and variant field
    /// (byte 8 high two bits = 10) per RFC 9562 §5.8 — the application
    /// owns the remaining 122 bits.
    public static func v8(bytes: Bytes) throws -> UUID {
        guard bytes.count == 16 else {
            throw UUIDError.invalidByteCount(bytes.count)
        }
        var s = SIMD16<UInt8>()
        bytes.withUnsafeBytes { src in
            for i in 0..<16 { s[i] = src[i] }
        }
        s[6] = (s[6] & 0x0F) | 0x80    // version 8 = 1000xxxx
        s[8] = (s[8] & 0x3F) | 0x80    // variant 10x
        return UUID(storage: s)
    }
}

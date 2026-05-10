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

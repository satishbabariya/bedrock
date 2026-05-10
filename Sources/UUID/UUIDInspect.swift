extension UUID {
    /// RFC 4122 / 9562 version (`.v1`...`.v8`). `nil` when the variant
    /// isn't `.rfc4122` (the version field has no defined meaning then).
    public var version: Version? {
        guard variant == .rfc4122 else { return nil }
        let v = (storage[6] >> 4) & 0x0F
        return Version(rawValue: Int(v))
    }

    /// Layout variant per RFC 4122 §4.1.1.
    public var variant: Variant {
        let bits = storage[8] >> 5  // top three bits
        switch bits {
        case 0b000, 0b001, 0b010, 0b011: return .ncs
        case 0b100, 0b101:                return .rfc4122
        case 0b110:                       return .microsoft
        case 0b111:                       return .future
        default:                          return .future  // unreachable
        }
    }
}

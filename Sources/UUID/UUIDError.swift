/// Errors raised by UUID parsing and byte construction.
public enum UUIDError: Error, Equatable, Sendable {
    /// Input string didn't match any accepted shape (length, hyphens,
    /// or recognized wrapping).
    case invalidFormat
    /// Input had the right shape but contained a non-hex character at
    /// the given UTF-8 byte offset (after URN prefix and brace stripping).
    case invalidHexCharacter(offset: Int, byte: UInt8)
    /// Byte input had the wrong length (UUIDs are exactly 16 bytes).
    case invalidByteCount(Int)
}

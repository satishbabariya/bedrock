/// Errors thrown by `Hex.decode`.
public enum HexError: Error, Equatable, Sendable {
    /// Input length must be even (one hex digit per nibble, two per byte).
    case oddLength(Int)
    /// Non-hex character at the given byte offset in the input.
    case invalidCharacter(offset: Int, byte: UInt8)
}

/// Errors raised by varint decoding.
public enum VarintError: Error, Equatable, Sendable {
    /// Input ran out before the varint completed (last byte had the
    /// continuation bit set).
    case truncated
    /// The varint exceeded its maximum byte count for the target width
    /// (5 bytes for 32-bit, 10 bytes for 64-bit), OR the decoded value
    /// is too large to fit the target integer type.
    case overflow
}

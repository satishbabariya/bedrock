/// Errors thrown by `Base64.decode`.
public enum Base64Error: Error, Equatable, Sendable {
    /// Input contains a character not in the active alphabet (and, in
    /// `.strict`/`.constantTime` modes, not whitespace).
    case invalidCharacter(offset: Int, byte: UInt8)
    /// Input length isn't a multiple of 4 (after whitespace stripping in
    /// `.lenient` mode), and unpadded input would be ambiguous.
    case invalidLength(Int)
    /// Padding was required by the input shape but missing or malformed
    /// (e.g. `=` mid-stream, or a single `=` in a position where two
    /// are required).
    case invalidPadding(offset: Int)
    /// A constant-time decode failed without revealing the failure offset
    /// (would leak timing). The whole input is rejected.
    case constantTimeRejected
}

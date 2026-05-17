/// Errors thrown by `COBS.decode` and friends.
public enum COBSError: Error, Hashable, Sendable {
    /// A 0x00 byte appeared inside encoded payload at `offset`
    /// (only emitted in `.none` framing — 0x00 is invalid in body bytes).
    case invalidZeroByte(offset: Int)

    /// A code byte points past the end of input.
    case truncated

    /// `.terminator` framing but no trailing 0x00 found.
    case missingTerminator

    /// `.terminator` framing but a 0x00 appeared before the final
    /// terminator position (i.e., mid-stream).
    case unexpectedTerminator(offset: Int)
}

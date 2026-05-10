import Bytes

/// Base64 (RFC 4648) codec namespace.
public enum Base64 {
    /// Alphabet variant.
    public enum Variant: Sendable {
        case standard   // RFC 4648 §4: A–Z a–z 0–9 + /
        case urlSafe    // RFC 4648 §5: A–Z a–z 0–9 - _
    }

    /// Decoder behavior on whitespace, non-alphabet chars, and timing safety.
    public enum DecodeMode: Sendable {
        /// Reject any byte not in the alphabet (including whitespace) and
        /// validate padding strictly. Variable-time. Default.
        case strict
        /// Skip ASCII whitespace (space, tab, CR, LF). Reject other
        /// non-alphabet bytes. Variable-time.
        case lenient
        /// Branch-free decoder for crypto inputs (keys, JWT signatures,
        /// X.509 fields). Rejects whitespace; runtime independent of the
        /// invalid-character position. Slower than `.strict`.
        case constantTime
    }

    /// MIME-style line wrapping on encode (RFC 2045 §6.8 = 76 chars + CRLF).
    public enum LineWrap: Sendable {
        case none
        case mime76                 // 76 columns, CRLF separator
    }
}

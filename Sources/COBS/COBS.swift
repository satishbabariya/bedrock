import Bytes

/// Consistent Overhead Byte Stuffing (COBS) codec namespace.
public enum COBS {

    /// Frame-delimiter handling.
    public enum Framing: Sendable, Hashable {
        /// Body only. Caller manages frame delimiters.
        case none

        /// Append a 0x00 terminator on encode; require and consume one
        /// on decode.
        case terminator
    }

    /// Worst-case encoded body size: `n + ⌈n/254⌉ + 1` (add 1 if framed).
    public static func maxEncodedSize(forSourceCount n: Int,
                                      framing: Framing = .none) -> Int {
        precondition(n >= 0)
        let overhead = (n + 253) / 254  // ⌈n/254⌉, safe for n>=0
        let body = n + overhead + 1
        return framing == .terminator ? body + 1 : body
    }

    /// Upper bound on decoded size: `max(0, n - 1)` body bytes
    /// (`max(0, n - 2)` if framed). Actual decoded size ≤ this.
    public static func maxDecodedSize(forEncodedCount n: Int,
                                      framing: Framing = .none) -> Int {
        precondition(n >= 0)
        let strip = framing == .terminator ? 2 : 1
        return Swift.max(0, n - strip)
    }
}

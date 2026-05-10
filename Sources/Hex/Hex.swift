import Bytes

/// Hex (base-16) codec namespace.
public enum Hex {
    /// Encoding case for hex output.
    public enum Case: Sendable {
        case lower    // "deadbeef"
        case upper    // "DEADBEEF"
    }
}

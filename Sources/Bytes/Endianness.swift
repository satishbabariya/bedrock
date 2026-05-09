/// Byte order used to interpret multi-byte integers in a `Bytes` buffer.
public enum Endianness: Sendable {
    /// Big-endian (network byte order). The default for wire protocols.
    case big
    /// Little-endian.
    case little
    /// Platform-native byte order. Use only for shared-memory IPC or on-disk
    /// caches keyed to the host architecture; protocol code should prefer
    /// `.big` or `.little` explicitly.
    case host
}

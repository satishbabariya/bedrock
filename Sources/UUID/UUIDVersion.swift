extension UUID {
    /// RFC 4122 / 9562 version (`.v1`...`.v8`).
    public enum Version: Int, Sendable, CaseIterable {
        case v1 = 1, v2 = 2, v3 = 3, v4 = 4, v5 = 5, v6 = 6, v7 = 7, v8 = 8
    }

    /// Layout variant per RFC 4122 §4.1.1.
    public enum Variant: Sendable, Equatable {
        case ncs            // 0xx — Apollo NCS legacy
        case rfc4122        // 10x — RFC 4122 / 9562 (modern standard)
        case microsoft      // 110 — Microsoft GUIDs
        case future         // 111 — reserved
    }
}

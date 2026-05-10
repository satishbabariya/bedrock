import Bytes

/// Hex (base-16) codec namespace.
public enum Hex {
    /// Encoding case for hex output.
    public enum Case: Sendable {
        case lower    // "deadbeef"
        case upper    // "DEADBEEF"
    }
}

extension Hex {
    /// Hex-encode `bytes` to a String. Default case is lowercase.
    public static func encode(_ bytes: Bytes, case: Case = .lower) -> String {
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        bytes.withUnsafeBytes { src in
            for byte in src {
                out.append(alphabet[Int(byte >> 4)])
                out.append(alphabet[Int(byte & 0x0F)])
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Sequence overload — useful for `[UInt8]`, `Array(...)`, etc.
    public static func encode<S: Sequence>(_ bytes: S, case: Case = .lower) -> String
    where S.Element == UInt8 {
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        var out: [UInt8] = []
        out.reserveCapacity(bytes.underestimatedCount * 2)
        for byte in bytes {
            out.append(alphabet[Int(byte >> 4)])
            out.append(alphabet[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Stream-encode into a `BytesMut`. Appends 2 ASCII bytes per input byte.
    public static func encode(_ bytes: Bytes, into out: inout BytesMut, case: Case = .lower) {
        guard !bytes.isEmpty else { return }
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        out.reserveCapacity(out.count + bytes.count * 2)
        bytes.withUnsafeBytes { src in
            for byte in src {
                out.putUInt8(alphabet[Int(byte >> 4)])
                out.putUInt8(alphabet[Int(byte & 0x0F)])
            }
        }
    }
}

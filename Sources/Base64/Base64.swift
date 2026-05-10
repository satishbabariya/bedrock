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

extension Base64 {
    /// Encode `bytes`. Default: standard alphabet, padded, no line wrap.
    public static func encode(
        _ bytes: Bytes,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    ) -> String {
        var out: [UInt8] = []
        encodeIntoArray(bytes, into: &out,
                        variant: variant, padding: padding, lineWrap: lineWrap)
        return String(decoding: out, as: UTF8.self)
    }

    /// Sequence overload — useful for `[UInt8]`, `Array(...)`, etc.
    public static func encode<S: Sequence>(
        _ bytes: S,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    ) -> String where S.Element == UInt8 {
        encode(Bytes(bytes), variant: variant, padding: padding, lineWrap: lineWrap)
    }

    /// Stream-encode into a `BytesMut`.
    public static func encode(
        _ bytes: Bytes,
        into out: inout BytesMut,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    ) {
        guard !bytes.isEmpty else { return }
        var arr: [UInt8] = []
        encodeIntoArray(bytes, into: &arr,
                        variant: variant, padding: padding, lineWrap: lineWrap)
        out.putBytes(arr)
    }

    /// Internal helper. Writes the encoded bytes into `out`.
    private static func encodeIntoArray(
        _ bytes: Bytes,
        into out: inout [UInt8],
        variant: Variant,
        padding: Bool,
        lineWrap: LineWrap
    ) {
        let alphabet = (variant == .standard)
            ? base64StandardAlphabet
            : base64UrlSafeAlphabet
        let estimated = 4 * ((bytes.count + 2) / 3)
        out.reserveCapacity(out.count + estimated)

        var lineCol = 0
        func emit(_ b: UInt8) {
            out.append(b)
            if case .mime76 = lineWrap {
                lineCol += 1
                if lineCol == 76 {
                    out.append(0x0D)  // CR
                    out.append(0x0A)  // LF
                    lineCol = 0
                }
            }
        }

        bytes.withUnsafeBytes { src in
            var i = 0
            while i + 3 <= src.count {
                let b0 = UInt32(src[i])
                let b1 = UInt32(src[i + 1])
                let b2 = UInt32(src[i + 2])
                let v = (b0 << 16) | (b1 << 8) | b2
                emit(alphabet[Int((v >> 18) & 0x3F)])
                emit(alphabet[Int((v >> 12) & 0x3F)])
                emit(alphabet[Int((v >>  6) & 0x3F)])
                emit(alphabet[Int(v & 0x3F)])
                i += 3
            }
            let rem = src.count - i
            if rem == 1 {
                let v = UInt32(src[i]) << 16
                emit(alphabet[Int((v >> 18) & 0x3F)])
                emit(alphabet[Int((v >> 12) & 0x3F)])
                if padding {
                    emit(base64Pad)
                    emit(base64Pad)
                }
            } else if rem == 2 {
                let v = (UInt32(src[i]) << 16) | (UInt32(src[i + 1]) << 8)
                emit(alphabet[Int((v >> 18) & 0x3F)])
                emit(alphabet[Int((v >> 12) & 0x3F)])
                emit(alphabet[Int((v >>  6) & 0x3F)])
                if padding {
                    emit(base64Pad)
                }
            }
        }
    }
}

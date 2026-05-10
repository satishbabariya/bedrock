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

    // MARK: - Decode

    /// Decode a Base64 string. Auto-detects variant; mixing throws.
    /// Padding is optional on input regardless of the encoder's choice.
    public static func decode(
        _ s: String,
        mode: DecodeMode = .strict
    ) throws -> Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(s.utf8.count)
        arr.append(contentsOf: s.utf8)
        return try decodeBytes(arr, mode: mode)
    }

    /// Decode Base64 bytes (ASCII). Same semantics as the String overload.
    public static func decode(
        _ bytes: Bytes,
        mode: DecodeMode = .strict
    ) throws -> Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(bytes.count)
        bytes.withUnsafeBytes { src in
            arr.append(contentsOf: src)
        }
        return try decodeBytes(arr, mode: mode)
    }

    /// Stream-decode into a `BytesMut`. Returns the number of decoded bytes.
    @discardableResult
    public static func decode(
        _ s: String,
        into out: inout BytesMut,
        mode: DecodeMode = .strict
    ) throws -> Int {
        let decoded = try decode(s, mode: mode)
        out.putBytes(decoded)
        return decoded.count
    }

    private static func decodeBytes(_ src: [UInt8], mode: DecodeMode) throws -> Bytes {
        if case .constantTime = mode {
            return try decodeConstantTime(src)
        }
        return try decodeVariableTime(src, mode: mode)
    }

    /// Variable-time decoder shared by `.strict` and `.lenient`.
    /// Tracks the variant once the first `+/-_` appears; mixing throws.
    private static func decodeVariableTime(_ src: [UInt8], mode: DecodeMode) throws -> Bytes {
        var out = BytesMut(capacity: (src.count / 4) * 3)
        var quantum: UInt32 = 0
        var sextetsInQuantum = 0
        var paddingsSeen = 0
        var seenStandardChar = false
        var seenUrlSafeChar = false

        for offset in 0..<src.count {
            let b = src[offset]
            let v = base64DecodeTable[Int(b)]

            // Handle whitespace
            if v == base64Whitespace {
                if mode == .lenient { continue }
                throw Base64Error.invalidCharacter(offset: offset, byte: b)
            }

            // Lock variant when seeing alphabet-distinguishing chars.
            switch b {
            case 0x2B, 0x2F:
                if seenUrlSafeChar {
                    throw Base64Error.invalidCharacter(offset: offset, byte: b)
                }
                seenStandardChar = true
            case 0x2D, 0x5F:
                if seenStandardChar {
                    throw Base64Error.invalidCharacter(offset: offset, byte: b)
                }
                seenUrlSafeChar = true
            default:
                break
            }

            // Handle padding
            if v == base64PadSentinel {
                if sextetsInQuantum < 2 {
                    throw Base64Error.invalidPadding(offset: offset)
                }
                paddingsSeen += 1
                if paddingsSeen > 2 {
                    throw Base64Error.invalidPadding(offset: offset)
                }
                continue
            }

            if v == base64Invalid {
                throw Base64Error.invalidCharacter(offset: offset, byte: b)
            }

            // Padding mid-stream → invalid
            if paddingsSeen > 0 {
                throw Base64Error.invalidCharacter(offset: offset, byte: b)
            }

            // Append sextet
            quantum = (quantum << 6) | UInt32(v)
            sextetsInQuantum += 1

            if sextetsInQuantum == 4 {
                out.putUInt8(UInt8((quantum >> 16) & 0xFF))
                out.putUInt8(UInt8((quantum >>  8) & 0xFF))
                out.putUInt8(UInt8(quantum & 0xFF))
                quantum = 0
                sextetsInQuantum = 0
                paddingsSeen = 0
            }
        }

        // Tail handling: if we ended mid-quantum, padding was either implied
        // (unpadded input) or already accounted for.
        switch sextetsInQuantum {
        case 0:
            break
        case 1:
            // Single sextet at the end is never valid (no whole bytes).
            throw Base64Error.invalidLength(src.count)
        case 2:
            // Two sextets → 1 output byte.
            quantum <<= 12
            out.putUInt8(UInt8((quantum >> 16) & 0xFF))
        case 3:
            // Three sextets → 2 output bytes.
            quantum <<= 6
            out.putUInt8(UInt8((quantum >> 16) & 0xFF))
            out.putUInt8(UInt8((quantum >>  8) & 0xFF))
        default:
            break
        }

        return out.freeze()
    }

    /// Constant-time decoder. Implemented in Task 11.
    private static func decodeConstantTime(_ src: [UInt8]) throws -> Bytes {
        // Stub for now; Task 11 fills this in.
        throw Base64Error.constantTimeRejected
    }

    // MARK: - Encode (internal helper)

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

# Bedrock `Hex` + `Base64` Modules — Design Spec

**Date:** 2026-05-10
**Layer:** 1 (Primitives, Bytes, Encodings) — *hex + base64 codecs*
**Status:** Approved, ready for implementation plan

---

## 1. Scope & Non-Goals

### In scope

- **Hex codec**: encode (lowercase or uppercase output), decode (case-insensitive). Reject odd-length input. Reject non-hex characters with structured error.
- **Base64 codec**:
  - Two alphabet variants: `.standard` (RFC 4648 §4) and `.urlSafe` (§5).
  - Optional padding on encode; lenient/strict acceptance on decode.
  - Decode modes: `.strict`, `.lenient` (skip ASCII whitespace), `.constantTime` (branch-free, side-channel resistant).
  - MIME line-wrap option on encode (76-char wrap, RFC 2045 §6.8).
- **`Bytes`-streaming overloads** (`encode(_:into:&BytesMut)`) to avoid an intermediate `String` allocation in I/O paths.
- **Extensions on `Bytes` and `String`** that delegate to the namespaced enums.
- Stdlib-only (no Foundation, no swift-system, no third-party). `Bytes`, `BytesMut`, `BytesReader` from the prior module are the substrate.

### Explicitly out of scope (separate designs later)

- Base32, Base58, Base85, Ascii85, `data-encoding` style multi-base.
- SIMD-accelerated paths (`base64-simd`, `simdutf`).
- DUDECT-style statistical timing analysis for `.constantTime` (Layer 25 tooling).
- Streaming codecs over `AsyncSequence` (Layer 11).
- COBS, percent encoding, varints, UUID — each owns a separate design.

---

## 2. Module Layout

Two new SwiftPM library targets in the existing monorepo, each independent and depending only on `Bytes`:

```
Bedrock/
└── Sources/
    ├── Bytes/                    # already shipped
    ├── Hex/
    │   ├── Hex.swift             # public enum Hex { encode/decode }
    │   ├── HexError.swift        # public enum HexError: Error
    │   ├── HexExtensions.swift   # extension Bytes / String delegations
    │   └── Internal/
    │       └── Tables.swift      # encode + decode lookup tables
    └── Base64/
        ├── Base64.swift          # public enum Base64 { encode/decode + Variant, DecodeMode, LineWrap }
        ├── Base64Error.swift     # public enum Base64Error: Error
        ├── Base64Extensions.swift
        └── Internal/
            ├── Tables.swift       # alphabet + decode tables
            └── ConstantTime.swift # branch-free decoder
└── Tests/
    ├── HexTests/
    │   ├── HexEncodeTests.swift
    │   ├── HexDecodeTests.swift
    │   └── HexRoundTripTests.swift
    └── Base64Tests/
        ├── Base64EncodeTests.swift
        ├── Base64DecodeTests.swift
        ├── Base64ConstantTimeTests.swift
        └── Base64RoundTripTests.swift
```

`Package.swift` gains two library products and four targets (two source, two test). Neither codec imports the other.

**Why two modules instead of one `Encodings`?** Independent codecs, no shared types, no shared logic. Splitting matches Bedrock's per-concern packaging and keeps downstream imports minimal — a logging crate that needs hex doesn't pull in base64.

---

## 3. Hex Public API

```swift
// Sources/Hex/Hex.swift

public enum Hex {

    /// Encoding case for hex output.
    public enum Case: Sendable {
        case lower    // "deadbeef"
        case upper    // "DEADBEEF"
    }

    // ─── Encoding ─────────────────────────────────────────────────────────

    /// Hex-encode `bytes` to a String. Default case is lowercase.
    public static func encode(_ bytes: Bytes, case: Case = .lower) -> String

    /// Sequence overload — useful for `[UInt8]`, `Array(...)`, etc.
    public static func encode<S: Sequence>(_ bytes: S, case: Case = .lower) -> String
        where S.Element == UInt8

    /// Stream-encode into a `BytesMut`. Appends 2 ASCII bytes per input byte.
    public static func encode(_ bytes: Bytes, into out: inout BytesMut, case: Case = .lower)

    // ─── Decoding ─────────────────────────────────────────────────────────

    /// Decode a hex string. Case-insensitive. Throws on odd length or
    /// non-hex characters.
    public static func decode(_ s: String) throws -> Bytes

    /// Decode hex bytes (ASCII). Same semantics as the String overload.
    public static func decode(_ bytes: Bytes) throws -> Bytes

    /// Stream-decode into a `BytesMut`. Returns the number of decoded bytes
    /// appended.
    @discardableResult
    public static func decode(_ s: String, into out: inout BytesMut) throws -> Int
}
```

```swift
// Sources/Hex/HexError.swift

public enum HexError: Error, Equatable, Sendable {
    /// Input length must be even (one hex digit per nibble, two per byte).
    case oddLength(Int)
    /// Non-hex character at the given byte offset in the input.
    case invalidCharacter(offset: Int, byte: UInt8)
}
```

```swift
// Sources/Hex/HexExtensions.swift

extension Bytes {
    public func hexEncoded(case: Hex.Case = .lower) -> String {
        Hex.encode(self, case: `case`)
    }
}

extension String {
    public init(hexEncoding bytes: Bytes, case: Hex.Case = .lower) {
        self = Hex.encode(bytes, case: `case`)
    }
}

extension Bytes {
    public init(hexDecoding s: String) throws {
        self = try Hex.decode(s)
    }
}
```

### 3.1 Notes on choices

- The `case` parameter name collides with the keyword and needs backticks at definition sites internally; call sites read cleanly (`Hex.encode(b, case: .upper)`).
- No streaming `decode<S: Sequence>(_:)` overload — `Bytes` already conforms to `RandomAccessCollection<UInt8>` and most callers pass either a `String` or a `Bytes`. `[UInt8]` users can wrap via `Bytes(_:)` first.
- `into:` streaming variants don't return `String` — they append directly to a `BytesMut` so HTTP encoders can write hex into a response buffer without an intermediate String allocation.

---

## 4. Base64 Public API

```swift
// Sources/Base64/Base64.swift

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

    // ─── Encoding ─────────────────────────────────────────────────────────

    /// Encode `bytes`. Default: standard alphabet, padded, no line wrap.
    public static func encode(
        _ bytes: Bytes,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    ) -> String

    public static func encode<S: Sequence>(
        _ bytes: S,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    ) -> String where S.Element == UInt8

    public static func encode(
        _ bytes: Bytes,
        into out: inout BytesMut,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    )

    // ─── Decoding ─────────────────────────────────────────────────────────

    /// Decode a Base64 string. Auto-detects variant: any of `+ /` forces
    /// standard; any of `- _` forces url-safe; otherwise either is accepted.
    /// Padding is optional on input regardless of the encoder's choice.
    public static func decode(
        _ s: String,
        mode: DecodeMode = .strict
    ) throws -> Bytes

    public static func decode(
        _ bytes: Bytes,
        mode: DecodeMode = .strict
    ) throws -> Bytes

    @discardableResult
    public static func decode(
        _ s: String,
        into out: inout BytesMut,
        mode: DecodeMode = .strict
    ) throws -> Int
}
```

```swift
// Sources/Base64/Base64Error.swift

public enum Base64Error: Error, Equatable, Sendable {
    /// Input contains a character not in the active alphabet (and, in
    /// `.strict`/`.constantTime` modes, not whitespace).
    case invalidCharacter(offset: Int, byte: UInt8)
    /// Input length isn't a multiple of 4 (after whitespace stripping in
    /// `.lenient` mode), and unpadded input would be ambiguous.
    case invalidLength(Int)
    /// Padding was required by the input shape but missing or malformed
    /// (e.g., `=` mid-stream, or a single `=` in a position where two are
    /// required).
    case invalidPadding(offset: Int)
    /// A constant-time decode failed without revealing the failure offset
    /// (would leak timing). The whole input is rejected.
    case constantTimeRejected
}
```

```swift
// Sources/Base64/Base64Extensions.swift

extension Bytes {
    public func base64Encoded(
        variant: Base64.Variant = .standard,
        padding: Bool = true,
        lineWrap: Base64.LineWrap = .none
    ) -> String {
        Base64.encode(self, variant: variant, padding: padding, lineWrap: lineWrap)
    }
}

extension String {
    public init(
        base64Encoding bytes: Bytes,
        variant: Base64.Variant = .standard,
        padding: Bool = true,
        lineWrap: Base64.LineWrap = .none
    ) {
        self = Base64.encode(bytes, variant: variant, padding: padding, lineWrap: lineWrap)
    }
}

extension Bytes {
    public init(
        base64Decoding s: String,
        mode: Base64.DecodeMode = .strict
    ) throws {
        self = try Base64.decode(s, mode: mode)
    }
}
```

### 4.1 Notes on choices

- **Decoder auto-detects variant.** Mixing `+/` with `-_` in one input throws `invalidCharacter`. JWT/cert parsers don't always know the variant up front; auto-detection avoids forcing them to try both.
- **Padding is optional on decode** regardless of the encoder's choice (RFC 4648 §3.2). Strict mode still validates the padding that's present.
- **`.constantTime` rejects whitespace** — skipping whitespace would itself be variable-time. Callers needing both should validate length/charset in `.strict` first.
- **`constantTimeRejected` carries no offset** — exposing the offset would leak timing.

---

## 5. Algorithms

### 5.1 Hex

**Encode:**

- Per input byte, two table lookups into a 16-byte ASCII alphabet (`"0123456789abcdef"` or uppercase). High nibble → high byte, low nibble → low byte. Branch-free, O(n).
- Output buffer pre-sized to `2 * input.count`. For the `String` path, build into a `[UInt8]` and use `String(decoding:as: UTF8.self)`. For the `BytesMut` path, `reserveCapacity` and append.

**Decode:**

- 256-entry lookup table mapping ASCII byte → nibble value (0–15) or `0xFF` (invalid). Built once at module-load by code so the table is auditable:

```swift
internal let hexDecodeTable: [UInt8] = (0..<256).map { i in
    switch UInt8(i) {
    case 0x30...0x39: return UInt8(i - 0x30)        // '0'-'9'
    case 0x41...0x46: return UInt8(i - 0x41 + 10)   // 'A'-'F'
    case 0x61...0x66: return UInt8(i - 0x61 + 10)   // 'a'-'f'
    default:          return 0xFF
    }
}
```

- Per input byte pair: two table reads, OR the high nibble shifted with the low nibble. If either read returns `0xFF`, throw `HexError.invalidCharacter`.
- Odd-length input fails fast before the loop with `HexError.oddLength`.
- The decoder operates byte-by-byte over the input's UTF-8 view (for `String`) or directly over the `Bytes` (the input must be ASCII; non-ASCII bytes are non-hex and rejected via the table).

### 5.2 Base64

**Encode:**

- 64-byte alphabet table per variant (`"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"` for standard, `…-_` for url-safe).
- Process input in 3-byte chunks producing 4 ASCII bytes. Tail handling: 1 leftover byte → 2 chars + `==`; 2 leftover → 3 chars + `=`. If `padding == false`, omit the `=` chars.
- Line wrap (`mime76`): emit `\r\n` after every 76 output chars, never splitting a 4-char quantum across lines (RFC 2045 §6.8).
- Pre-size output to `4 * ((input.count + 2) / 3)` plus CRLF overhead if wrapping.

**Decode (`.strict` and `.lenient`):**

- 256-entry decode table mapping ASCII byte → 6-bit value (0–63), `0xFE` (whitespace, only consumed in `.lenient`), `0xFD` (the `=` padding byte, terminator-only), or `0xFF` (invalid).
- Variant auto-detect: scan the input for any of `+ / - _`; mixing throws. Standard table is used by default; url-safe is selected when `- _` are seen.
- Process input in 4-char quanta, reading from the table. Whitespace bytes either skip-advance (`.lenient`) or fail (`.strict`). Padding bytes (`=`) close out a quantum with appropriate output truncation; their position is validated against the input length.
- Output sized to `(input_len_after_strip / 4) * 3`, trimmed for partial quanta.

**Decode (`.constantTime`):**

- Branch-free byte-wise decode adapted from `base64ct`'s approach. Each input byte is classified using a sequence of `&`/`|`/comparison operations producing a 6-bit value or an "invalid" mask, all without data-dependent branches.
- The "invalid" mask accumulates across the whole input. After processing every byte, a single check determines whether to throw `Base64Error.constantTimeRejected`. The runtime is a function of input length only — never of which byte was invalid.
- Whitespace bytes count as invalid (no skipping). Both alphabets are classified in parallel; either is accepted.
- Output is allocated up-front to `(input_len / 4) * 3`. If the input is malformed, the output is zeroed before throw to avoid leaking partial decode in memory.

### 5.3 Lookup tables — review-time discipline

All tables are computed in code (no inscrutable hex literals) so the values are auditable. A Swift Testing `@Test` per codec verifies the table against a ground-truth function:

```swift
@Test func hexDecodeTableCorrect() {
    for ascii: UInt8 in 0..<255 {
        let expected = expectedNibble(for: ascii)
        #expect(hexDecodeTable[Int(ascii)] == expected)
    }
}
```

This guards against an off-by-one in the table-builder switch.

---

## 6. Error Model

Two new error types, one per codec, both `Error + Equatable + Sendable`.

| Type | Cases | When thrown |
|---|---|---|
| `HexError` | `.oddLength(Int)` | Input length is odd. |
| | `.invalidCharacter(offset: Int, byte: UInt8)` | Byte outside `[0-9A-Fa-f]` at the given offset. |
| `Base64Error` | `.invalidCharacter(offset: Int, byte: UInt8)` | Byte outside the active alphabet (and not whitespace in `.lenient`). |
| | `.invalidLength(Int)` | After any whitespace stripping, length is not a multiple of 4 and the input is unpadded. |
| | `.invalidPadding(offset: Int)` | `=` appears mid-stream, or the count of trailing `=` doesn't match the input shape. |
| | `.constantTimeRejected` | The constant-time decoder rejected the input as a whole. No offset (intentional). |

Per-codec error types (rather than a shared `EncodingError`) give callers exhaustive switches that make sense and let tests assert specific cases via `#expect(throws:)`.

**Encoding does not throw.** Any `Bytes` value produces a valid encoding. Allocation failure traps in stdlib (no recoverable API).

---

## 7. Testing Strategy

Swift Testing (`@Test` / `#expect`). Three test files for Hex, four for Base64.

### 7.1 `HexEncodeTests.swift`

- Empty input → empty string (both cases).
- Known vectors: `[0xDE, 0xAD, 0xBE, 0xEF]` → `"deadbeef"` / `"DEADBEEF"`.
- Single-byte boundaries: `0x00`, `0x0F`, `0xF0`, `0xFF` → `"00"`, `"0f"`, `"f0"`, `"ff"`.
- Stream into `BytesMut`: appended count is exactly `2 * input.count`; existing buffer contents preserved (encode appends, doesn't overwrite).
- Sequence overload (`[UInt8]`) produces the same result as the `Bytes` overload.

### 7.2 `HexDecodeTests.swift`

- Round-trip the encode vectors.
- Case-insensitive: `"DEADBEEF"`, `"deadbeef"`, `"DeAdBeEf"` all decode equal.
- `oddLength`: `"abc"` throws `HexError.oddLength(3)`.
- `invalidCharacter`: `"de@dbeef"` throws `HexError.invalidCharacter(offset: 2, byte: 0x40)`.
- Bytes overload mirrors String overload.
- `decode(_:into:)` returns the byte count and appends to the buffer.
- Decode-table sanity test (the per-byte ground-truth check from §5.3).

### 7.3 `HexRoundTripTests.swift`

- Round-trip a 4 KiB random buffer (seeded RNG so the test is deterministic) through encode → decode and compare equal.
- Round-trip every single byte 0x00…0xFF.

### 7.4 `Base64EncodeTests.swift`

- RFC 4648 §10 test vectors: empty, `"f"`, `"fo"`, `"foo"`, `"foob"`, `"fooba"`, `"foobar"` → `""`, `"Zg=="`, `"Zm8="`, `"Zm9v"`, `"Zm9vYg=="`, `"Zm9vYmE="`, `"Zm9vYmFy"`.
- URL-safe variant: input containing bytes that produce `+` and `/` in standard should produce `-` and `_`.
- `padding: false` strips the `=` chars; encoded length is `ceil(input * 4/3)`.
- `lineWrap: .mime76`: input that produces ≥ 100 output chars has `\r\n` at column 76 boundaries; quantum (4 chars) never split.
- Stream into `BytesMut` matches the String result byte-for-byte.

### 7.5 `Base64DecodeTests.swift`

- RFC test vectors decode correctly.
- Auto-variant detection: standard input with `+/`, url-safe with `-_`, and ambiguous (alphanumeric only) all succeed; mixing `+` and `-` in one input throws `invalidCharacter`.
- Padding-optional decode: `"Zg=="` and `"Zg"` both decode to `[0x66]`.
- `.strict` rejects whitespace: `"Zg ="` throws `invalidCharacter` at offset 2.
- `.lenient` accepts whitespace: `"Zm9v\nYmFy"` decodes to `"foobar"`.
- `invalidPadding`: `"Z=g="` throws (`=` mid-stream).
- `invalidLength`: `"Zg=" ` (3 chars unpadded) throws.

### 7.6 `Base64ConstantTimeTests.swift`

- Happy path: known vectors decode correctly under `.constantTime`.
- Whitespace rejection: `.constantTime` mode throws `constantTimeRejected` on a whitespace-containing input that `.lenient` would accept.
- Invalid alphabet: a stream with one bad character throws `constantTimeRejected` (no offset disclosure).
- Smoke timing-invariance check: 1000-byte all-valid input vs. 1000-byte input with byte 50 invalidated complete in similar wall-clock time. Documented as a smoke test, not a real timing-attack defense; full DUDECT-style analysis is a Layer 25 follow-up.

### 7.7 `Base64RoundTripTests.swift`

- Every byte length 0…256 encodes and decodes back to the original.
- Random buffer (seeded), each variant (`.standard`, `.urlSafe`) × each padding setting × each decode mode (where compatible) round-trips.

**Coverage gate:** ≥ 90% on `Sources/Hex/` and `Sources/Base64/` independently, validated by `swift test --enable-code-coverage`.

---

## 8. Deferrals

Each becomes its own design later:

1. **Base32, Base58, Base85, Ascii85** — own designs.
2. **`data-encoding` style multi-base** — not pursuing; per-codec modules are clearer.
3. **SIMD-accelerated codecs** (`simdutf`, `base64-simd`) — port when profiling shows hotspot.
4. **DUDECT-style timing analysis for `.constantTime`** — Layer 25 tooling.
5. **Streaming `AsyncSequence` codecs** — Layer 11 owns the reactor; revisit then.
6. **COBS, percent encoding, varints, UUID** — own designs (already noted in Layer 1 deferrals).

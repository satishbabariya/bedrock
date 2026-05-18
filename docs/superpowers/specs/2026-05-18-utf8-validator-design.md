# UTF8Validator Module Design

**Status:** Approved
**Layer:** 1 — Primitives
**Depends on:** `Bytes`
**Date:** 2026-05-18

## Purpose

Provide an in-process strict-UTF-8 byte-sequence validator — the Layer 1 primitive every higher layer needs before it can safely interpret bytes as text. Validates per [RFC 3629](https://datatracker.ietf.org/doc/html/rfc3629): rejects overlong encodings, surrogate code points (U+D800–U+DFFF), and code points above U+10FFFF.

The codec is a Layer 1 primitive: stdlib-only, synchronous, no I/O. Operates on `Bytes`. v1 ships a correct scalar DFA validator. A SIMD fast path is a planned follow-up behind the same API (the module is named `UTF8Validator` accordingly — `UTF8` would collide with stdlib's `Swift.UTF8` codec type).

## Scope

### In scope (v1)

- A `UTF8Validator` namespaced enum.
- `isValid(_:) -> Bool` — fast yes/no path.
- `validate(_:) -> ValidationResult` — yes/no + first-invalid-byte offset on failure.
- `ValidationResult` — `.valid` / `.invalid(offset: Int)` value type, `Hashable + Sendable`.
- `Bytes` convenience extensions: `var isValidUTF8: Bool` and `func validateUTF8() -> ValidationResult`.
- Strict UTF-8 semantics: rejects overlongs, surrogates, > U+10FFFF, invalid lead bytes, stray continuations, truncated sequences.
- Stdlib-only; depends only on `Bytes`.

### Out of scope (separate work when needed)

- **SIMD fast path** (Lemire/Keiser 16-byte-at-a-time validator) — separate spec, drop-in behind the same API.
- **Streaming / partial-buffer validation** — stateful `UTF8Decoder` type. Add when Layer 2 needs it.
- **Code-point counting** — `count(_:) -> (count, validUpTo)` style API. Cheap to add later; not load-bearing now.
- **Lossy decoding / replacement-character substitution** — `String`-construction concern, belongs in Layer 2.
- **WTF-8** (allows unpaired surrogates) — niche; not the standard.
- **CESU-8 / Modified UTF-8** — niche; not the standard.
- **BOM detection / handling** — bytes are bytes; BOM is a higher-layer concern.
- **Position-as-(line, column)** — parser concern; trivial to compute downstream from byte offset.
- **Construction of `Bytes` "validating UTF-8"** — no-op (bytes are bytes regardless of validity). String construction is Layer 2's job.

## Module Layout

```
Sources/UTF8Validator/
├── UTF8Validator.swift             # namespace + ValidationResult + entry points
├── UTF8ValidatorDFA.swift          # internal DFA tables + scalar validator
└── UTF8ValidatorExtensions.swift   # Bytes conveniences
```

```
Tests/UTF8ValidatorTests/
├── UTF8ValidatorASCIITests.swift
├── UTF8ValidatorMultiByteTests.swift
├── UTF8ValidatorRejectionTests.swift
├── UTF8ValidatorOffsetTests.swift
├── UTF8ValidatorExhaustiveTests.swift
└── UTF8ValidatorExtensionsTests.swift
```

## Public API

```swift
import Bytes

public enum UTF8Validator {

    /// Outcome of validating a byte sequence as UTF-8.
    public enum ValidationResult: Equatable, Hashable, Sendable {
        case valid

        /// Validation failed; `offset` is the byte index where the first
        /// malformed sequence began (WHATWG convention — useful for
        /// callers that want to back up and insert a replacement
        /// character).
        case invalid(offset: Int)
    }

    /// Fast yes/no validation. Equivalent to
    /// `validate(_:) == .valid` but allowed to skip offset bookkeeping.
    public static func isValid(_ bytes: Bytes) -> Bool

    /// Validate `bytes` as strict UTF-8 per RFC 3629. Rejects overlongs,
    /// surrogates (U+D800–U+DFFF), and code points > U+10FFFF.
    public static func validate(_ bytes: Bytes) -> ValidationResult
}
```

### Bytes extensions

```swift
extension Bytes {
    /// `true` iff the bytes are well-formed strict UTF-8.
    public var isValidUTF8: Bool { UTF8Validator.isValid(self) }

    /// Validate as strict UTF-8; on failure the result carries the
    /// offset of the first byte of the malformed sequence.
    public func validateUTF8() -> UTF8Validator.ValidationResult {
        UTF8Validator.validate(self)
    }
}
```

No `String` extensions — UTF-8 validation operates on bytes, not text.

## Algorithm

Bjoern Hoehrmann's [Flexible and Economical UTF-8 Decoder](https://bjoern.hoehrmann.de/utf-8/decoder/dfa/), simplified to validation-only.

Two static tables, ~360 bytes total:

- `byteClass[256]` — maps each input byte to one of 12 classes (ASCII / continuation-of-various-ranges / lead-2-byte / lead-3-byte-various / lead-4-byte-various / invalid-lead).
- `transition[9 states × 12 classes]` — `next = transition[state + class]`. State `0` = ACCEPT, state `12` = REJECT, intermediate states encode "waiting on N more continuations of type T".

**Validation loop:**
```
state = ACCEPT (0)
sequenceStart = 0
for i in 0 ..< bytes.count:
    cls = byteClass[bytes[i]]
    state = transition[state + cls]
    if state == REJECT:
        return .invalid(offset: sequenceStart)
    if state == ACCEPT:
        sequenceStart = i + 1
if state != ACCEPT:
    return .invalid(offset: sequenceStart)   # truncated mid-sequence
return .valid
```

`isValid(_:)` runs the same loop without the `sequenceStart` bookkeeping (skip the assignment in the ACCEPT branch).

### Why this DFA is correct

- **Overlongs** rejected: lead-byte classes for `C0..C1` map to the invalid class. Overlong 3- and 4-byte forms are rejected at the second byte (e.g., for `E0`, the second-byte transition rejects continuations in `80..9F`; for `F0`, the second-byte transition rejects `80..8F`).
- **Surrogates** rejected: `ED A0..ED BF` — the second-byte transition out of `state(ED)` doesn't accept the `A0..BF` continuation class.
- **Code points > U+10FFFF** rejected: lead bytes `F5..FF` map to the invalid class; `F4` only accepts second bytes up to `8F` (so `F4 90 80 80` = U+110000 is rejected at byte 1).
- **Stray continuations** rejected: the ACCEPT-state transition for continuation classes goes to REJECT.
- **Truncated sequences** detected: after the loop, `state != ACCEPT` means we ended mid-sequence.

### Error-offset semantics

`.invalid(offset:)` reports the **first byte of the malformed sequence** (WHATWG convention). The DFA tracks this via `sequenceStart`, updated each time state returns to ACCEPT.

Concrete behaviors:

| Input | Result |
|---|---|
| Bad lead byte at index 5 | `.invalid(offset: 5)` |
| Good lead at 5, bad continuation at 6 | `.invalid(offset: 5)` |
| 3-byte sequence starts at 5 but input ends at byte 7 | `.invalid(offset: 5)` |
| Stray continuation at 5 (no preceding lead) | `.invalid(offset: 5)` |

## Testing Strategy

Each test file targets ≥ 90% line coverage on its corresponding source file.

### `UTF8ValidatorASCIITests.swift`
- Empty input → `.valid`.
- Single ASCII byte for each of `0x00...0x7F`.
- Long ASCII string (1 KiB of `0x41`).

### `UTF8ValidatorMultiByteTests.swift`
- Specific well-formed 2-byte sequences: U+0080 (`C2 80`), U+00A9 © (`C2 A9`), U+07FF (`DF BF`).
- Specific well-formed 3-byte sequences: U+0800 (`E0 A0 80`), U+20AC € (`E2 82 AC`), U+FFFD (`EF BF BD`), U+FFFF (`EF BF BF`).
- Specific well-formed 4-byte sequences: U+10000 (`F0 90 80 80`), U+1F600 😀 (`F0 9F 98 80`), U+10FFFF (`F4 8F BF BF`).
- Concatenated mixed sequences (ASCII + 2-byte + 3-byte + 4-byte interleaved).

### `UTF8ValidatorRejectionTests.swift`
- **Overlongs:** U+0000 as 2-byte (`C0 80`), 3-byte (`E0 80 80`), 4-byte (`F0 80 80 80`); U+007F as 2-byte (`C1 BF`); U+07FF as 3-byte (`E0 9F BF`); U+FFFF as 4-byte (`F0 8F BF BF`).
- **Surrogates:** U+D800 (`ED A0 80`), U+DFFF (`ED BF BF`), U+DAAA midpoint.
- **Out of range:** U+110000 (`F4 90 80 80`); 5-byte sequence (`F8 87 BF BF BF`); 6-byte sequence (`FC 84 80 80 80 80`).
- **Invalid lead bytes:** every byte in `0xC0`, `0xC1`, `0xF5...0xFF`.
- **Stray continuations:** every byte in `0x80...0xBF` alone.
- **Truncated:** lead byte with no continuation; lead byte with one continuation when two needed; lead byte with two continuations when three needed.
- **Mid-sequence garbage:** valid prefix + bad byte + valid suffix.

### `UTF8ValidatorOffsetTests.swift`
- Each rejection case asserts the exact `.invalid(offset:)` value.
- ASCII prefix + bad byte at known position → offset matches.
- Truncated sequence starting at known position → offset = sequence start, not `bytes.count`.

### `UTF8ValidatorExhaustiveTests.swift`
- For every Unicode scalar `U+0000...U+10FFFF` (skipping `U+D800...U+DFFF`): manually encode to UTF-8 bytes using a small hand-rolled encoder in the test file (no dependency on Swift's `Unicode.UTF8.encode`), validate, assert `.valid` and `isValid == true`.
- ~1.1 million validations; should complete in under a second on the scalar DFA.
- The hand-rolled encoder is the independent oracle — its logic is straightforward and worth having separate from the validator under test.

### `UTF8ValidatorExtensionsTests.swift`
- `Bytes.isValidUTF8` matches `UTF8Validator.isValid`.
- `Bytes.validateUTF8()` matches `UTF8Validator.validate`.

## Non-Functional Requirements

- **Stdlib only.** No Foundation. No swift-system. No swift-atomics.
- **Sendable.** `UTF8Validator` is a static-only namespace; `ValidationResult` is `Sendable + Hashable`.
- **Bounds-safe.** The DFA loop indexes `bytes` only at `i < bytes.count`; table indices are arithmetic over `state + class` where `state ∈ {0, 12, ..., 96}` and `class ∈ {0..11}`, so the maximum index is `96 + 11 = 107` against a 108-element table.
- **O(n) time, O(1) auxiliary space.** Two static tables, two state variables. No allocation.
- **No SIMD intrinsics in v1.** Scalar DFA only — keeps the code reviewable and the test surface tractable.

## Open Questions

None. All design questions resolved during brainstorming:
- API: `isValid` (Bool) + `validate` (offset on failure). No code-point count, no streaming.
- Module name: `UTF8Validator` (avoids stdlib `Swift.UTF8` ergonomic conflict).
- Implementation: scalar DFA (Hoehrmann) in v1; SIMD optimization deferred behind the same API.
- Error offset: first byte of the malformed sequence (WHATWG convention).

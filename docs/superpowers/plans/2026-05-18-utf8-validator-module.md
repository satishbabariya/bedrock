# UTF8Validator Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `UTF8Validator` Layer 1 strict-UTF-8 validator per the spec at `docs/superpowers/specs/2026-05-18-utf8-validator-design.md`.

**Architecture:** Three source files under `Sources/UTF8Validator/`. A `UTF8Validator` namespaced enum exposing `isValid(_:) -> Bool` and `validate(_:) -> ValidationResult`. Backed by a scalar Hoehrmann-style DFA with two static tables (~360 bytes total). `Bytes` extensions for ergonomic call sites. Stdlib-only; depends on `Bytes`.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing (`import Testing`, `@Test`, `#expect`, `@Suite`).

---

## File Structure

**Sources** (`Sources/UTF8Validator/`):
- `UTF8Validator.swift` — namespace + `ValidationResult` + `isValid` + `validate`
- `UTF8ValidatorDFA.swift` — internal byte-class and transition tables + the validation loop
- `UTF8ValidatorExtensions.swift` — `Bytes.isValidUTF8`, `Bytes.validateUTF8()`

**Tests** (`Tests/UTF8ValidatorTests/`):
- `UTF8ValidatorASCIITests.swift`
- `UTF8ValidatorMultiByteTests.swift`
- `UTF8ValidatorRejectionTests.swift`
- `UTF8ValidatorOffsetTests.swift`
- `UTF8ValidatorExhaustiveTests.swift`
- `UTF8ValidatorExtensionsTests.swift`

---

## DFA Reference

The DFA has 12 byte classes and 9 states. State and class are combined as `state + class` to index a flat 108-entry transition table; "states" are encoded as multiples of 12 so the indexing arithmetic stays simple.

### Byte classes

| Class | Bytes | Meaning |
|---|---|---|
| 0 | `0x00..0x7F` | ASCII |
| 1 | `0x80..0x8F` | continuation (low half of low range) |
| 2 | `0x90..0x9F` | continuation (high half of low range) |
| 3 | `0xA0..0xBF` | continuation (high range) |
| 4 | `0xC2..0xDF` | lead 2-byte |
| 5 | `0xE0` | lead 3-byte (overlong-protected) |
| 6 | `0xE1..0xEC, 0xEE..0xEF` | lead 3-byte (general) |
| 7 | `0xED` | lead 3-byte (surrogate-protected) |
| 8 | `0xF0` | lead 4-byte (overlong-protected) |
| 9 | `0xF1..0xF3` | lead 4-byte (general) |
| 10 | `0xF4` | lead 4-byte (range-protected at U+10FFFF) |
| 11 | `0xC0, 0xC1, 0xF5..0xFF` | always-invalid lead |

### States

| State | Value | Meaning |
|---|---|---|
| ACCEPT | 0 | between sequences |
| s_2cont | 12 | 2-byte lead consumed; need 1 cont (any) |
| s_3cont | 24 | 3-byte lead consumed (general); need 2 conts, first any |
| s_3cont_E0 | 36 | E0 consumed; need first of 2 conts to be A0-BF |
| s_3cont_ED | 48 | ED consumed; need first of 2 conts to be 80-9F |
| s_4cont | 60 | F1-F3 consumed; need 3 conts, first any |
| s_4cont_F0 | 72 | F0 consumed; need first of 3 conts to be 90-BF |
| s_4cont_F4 | 84 | F4 consumed; need first of 3 conts to be 80-8F |
| REJECT | 96 | terminal failure |

### Transition table (108 entries, row-major by state, column-major by class)

```
//         cls:  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11
/* s0    */     0, 96, 96, 96, 12, 36, 24, 48, 72, 60, 84, 96,
/* s12   */    96,  0,  0,  0, 96, 96, 96, 96, 96, 96, 96, 96,
/* s24   */    96, 12, 12, 12, 96, 96, 96, 96, 96, 96, 96, 96,
/* s36   */    96, 96, 96, 12, 96, 96, 96, 96, 96, 96, 96, 96,  // E0
/* s48   */    96, 12, 12, 96, 96, 96, 96, 96, 96, 96, 96, 96,  // ED
/* s60   */    96, 24, 24, 24, 96, 96, 96, 96, 96, 96, 96, 96,
/* s72   */    96, 96, 24, 24, 96, 96, 96, 96, 96, 96, 96, 96,  // F0
/* s84   */    96, 24, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96,  // F4
/* s96   */    96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96,
```

### Validation loop

```
state = 0                         // ACCEPT
sequenceStart = 0
for i in 0 ..< bytes.count {
    let cls = byteClass[bytes[i]]
    state = transition[state + cls]
    if state == 96 { return .invalid(offset: sequenceStart) }
    if state == 0  { sequenceStart = i + 1 }
}
if state != 0 { return .invalid(offset: sequenceStart) }
return .valid
```

---

## Task 1: Package scaffolding

**Files:**
- Modify: `Package.swift`
- Create: `Sources/UTF8Validator/UTF8Validator.swift` (stub)
- Create: `Sources/UTF8Validator/UTF8ValidatorDFA.swift` (stub)
- Create: `Sources/UTF8Validator/UTF8ValidatorExtensions.swift` (stub)
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorScaffoldTests.swift` (stub)

- [ ] **Step 1: Add product + target to Package.swift**

Add to `products:` after the COBS line:
```swift
.library(name: "UTF8Validator", targets: ["UTF8Validator"]),
```

Add to `targets:` after the COBS test target:
```swift
.target(name: "UTF8Validator", dependencies: ["Bytes"], path: "Sources/UTF8Validator"),
.testTarget(name: "UTF8ValidatorTests", dependencies: ["UTF8Validator", "Bytes"], path: "Tests/UTF8ValidatorTests"),
```

- [ ] **Step 2: Create stub source files**

`Sources/UTF8Validator/UTF8Validator.swift`:
```swift
import Bytes

/// Strict UTF-8 byte-sequence validator (RFC 3629).
public enum UTF8Validator {
}
```

`Sources/UTF8Validator/UTF8ValidatorDFA.swift`:
```swift
import Bytes
```

`Sources/UTF8Validator/UTF8ValidatorExtensions.swift`:
```swift
import Bytes
```

- [ ] **Step 3: Create stub test**

`Tests/UTF8ValidatorTests/UTF8ValidatorScaffoldTests.swift`:
```swift
import Testing
import UTF8Validator

@Test
func scaffoldCompiles() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Build & verify**

Run: `swift build`
Expected: builds cleanly, no warnings.

Run: `swift test --filter UTF8ValidatorTests`
Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/UTF8Validator Tests/UTF8ValidatorTests
git commit -m "$(cat <<'EOF'
feat(utf8-validator): scaffold UTF8Validator module

Add library product, source target, and test target with stub files.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: ValidationResult type

**Files:**
- Modify: `Sources/UTF8Validator/UTF8Validator.swift`
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorResultTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UTF8ValidatorTests/UTF8ValidatorResultTests.swift`:
```swift
import Testing
import UTF8Validator

@Suite
struct UTF8ValidatorResultTests {

    @Test
    func validIsConstructible() {
        let r: UTF8Validator.ValidationResult = .valid
        #expect(r == .valid)
    }

    @Test
    func invalidCarriesOffset() {
        let r: UTF8Validator.ValidationResult = .invalid(offset: 7)
        if case .invalid(let o) = r {
            #expect(o == 7)
        } else {
            Issue.record("expected .invalid case")
        }
    }

    @Test
    func equality() {
        #expect(UTF8Validator.ValidationResult.valid
                == UTF8Validator.ValidationResult.valid)
        #expect(UTF8Validator.ValidationResult.invalid(offset: 3)
                == UTF8Validator.ValidationResult.invalid(offset: 3))
        #expect(UTF8Validator.ValidationResult.invalid(offset: 3)
                != UTF8Validator.ValidationResult.invalid(offset: 4))
        #expect(UTF8Validator.ValidationResult.valid
                != UTF8Validator.ValidationResult.invalid(offset: 0))
    }

    @Test
    func hashableUsableInSet() {
        var s = Set<UTF8Validator.ValidationResult>()
        s.insert(.valid)
        s.insert(.valid)
        s.insert(.invalid(offset: 1))
        s.insert(.invalid(offset: 1))
        s.insert(.invalid(offset: 2))
        #expect(s.count == 3)
    }

    @Test
    func sendable() {
        let r: UTF8Validator.ValidationResult = .valid
        Task.detached { @Sendable in
            let _ = r
        }
    }
}
```

- [ ] **Step 2: Delete scaffold and run to verify failure**

```bash
rm Tests/UTF8ValidatorTests/UTF8ValidatorScaffoldTests.swift
swift test --filter UTF8ValidatorTests 2>&1 | tail -30
```
Expected: compile error — `UTF8Validator.ValidationResult` doesn't exist.

- [ ] **Step 3: Implement ValidationResult**

Replace contents of `Sources/UTF8Validator/UTF8Validator.swift`:
```swift
import Bytes

/// Strict UTF-8 byte-sequence validator (RFC 3629).
public enum UTF8Validator {

    /// Outcome of validating a byte sequence as UTF-8.
    public enum ValidationResult: Equatable, Hashable, Sendable {
        case valid

        /// Validation failed; `offset` is the byte index where the first
        /// malformed sequence began (WHATWG convention).
        case invalid(offset: Int)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter UTF8ValidatorTests 2>&1 | tail -10`
Expected: all 5 `UTF8ValidatorResultTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/UTF8Validator Tests/UTF8ValidatorTests
git commit -m "$(cat <<'EOF'
feat(utf8-validator): add ValidationResult type

.valid / .invalid(offset:) value type. Equatable, Hashable, Sendable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: DFA tables + scalar validator

**Files:**
- Modify: `Sources/UTF8Validator/UTF8ValidatorDFA.swift`
- Modify: `Sources/UTF8Validator/UTF8Validator.swift` (add `isValid` and `validate` entry points)
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorSmokeTests.swift` (single-byte sanity)

This is the heart of the module. Tests for full multi-byte coverage land in subsequent tasks; this task just gets the DFA wired up and verified on the simplest cases.

- [ ] **Step 1: Write smoke tests**

Create `Tests/UTF8ValidatorTests/UTF8ValidatorSmokeTests.swift`:
```swift
import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorSmokeTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func emptyIsValid() {
        #expect(UTF8Validator.validate(b([])) == .valid)
        #expect(UTF8Validator.isValid(b([])))
    }

    @Test
    func singleASCIIByteIsValid() {
        #expect(UTF8Validator.validate(b([0x41])) == .valid)
        #expect(UTF8Validator.isValid(b([0x41])))
    }

    @Test
    func standaloneContinuationIsInvalid() {
        // 0x80 with no preceding lead byte.
        let r = UTF8Validator.validate(b([0x80]))
        #expect(r == .invalid(offset: 0))
        #expect(UTF8Validator.isValid(b([0x80])) == false)
    }

    @Test
    func wellFormedTwoByteSequenceIsValid() {
        // U+00A9 © = C2 A9
        #expect(UTF8Validator.validate(b([0xC2, 0xA9])) == .valid)
    }

    @Test
    func truncatedLeadByteIsInvalidAtSequenceStart() {
        // C2 alone (lead 2-byte with no cont)
        #expect(UTF8Validator.validate(b([0xC2])) == .invalid(offset: 0))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter UTF8ValidatorTests 2>&1 | tail -10`
Expected: compile error — `UTF8Validator.validate` / `UTF8Validator.isValid` don't exist.

- [ ] **Step 3: Implement DFA tables**

Replace `Sources/UTF8Validator/UTF8ValidatorDFA.swift`:
```swift
import Bytes

@usableFromInline
internal enum UTF8ValidatorDFA {

    // State and class together index `transition` as `state + class`.
    // States are stored as multiples of 12 (the class count) so the
    // arithmetic stays branch-free.
    @usableFromInline static let ACCEPT: UInt8 = 0
    @usableFromInline static let REJECT: UInt8 = 96

    // Byte-class lookup. 256 entries, one per possible byte value.
    @usableFromInline static let byteClass: [UInt8] = [
        // 0x00..0x7F — ASCII (class 0)
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        // 0x80..0x8F — continuation low-low (class 1)
        1, 1, 1, 1, 1, 1, 1, 1,  1, 1, 1, 1, 1, 1, 1, 1,
        // 0x90..0x9F — continuation low-high (class 2)
        2, 2, 2, 2, 2, 2, 2, 2,  2, 2, 2, 2, 2, 2, 2, 2,
        // 0xA0..0xBF — continuation high (class 3)
        3, 3, 3, 3, 3, 3, 3, 3,  3, 3, 3, 3, 3, 3, 3, 3,
        3, 3, 3, 3, 3, 3, 3, 3,  3, 3, 3, 3, 3, 3, 3, 3,
        // 0xC0..0xC1 — invalid (class 11)
        11, 11,
        // 0xC2..0xDF — lead 2-byte (class 4)
        4, 4, 4, 4, 4, 4, 4, 4,  4, 4, 4, 4, 4, 4,
        4, 4, 4, 4, 4, 4, 4, 4,  4, 4, 4, 4, 4, 4, 4, 4,
        // 0xE0 — lead 3-byte overlong-protected (class 5)
        5,
        // 0xE1..0xEC — lead 3-byte general (class 6)
        6, 6, 6, 6, 6, 6, 6, 6,  6, 6, 6, 6,
        // 0xED — lead 3-byte surrogate-protected (class 7)
        7,
        // 0xEE..0xEF — lead 3-byte general (class 6)
        6, 6,
        // 0xF0 — lead 4-byte overlong-protected (class 8)
        8,
        // 0xF1..0xF3 — lead 4-byte general (class 9)
        9, 9, 9,
        // 0xF4 — lead 4-byte range-protected (class 10)
        10,
        // 0xF5..0xFF — invalid (class 11)
        11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,
    ]

    // Transition table. 9 states × 12 classes = 108 entries.
    // Index as `transition[state + class]`.
    @usableFromInline static let transition: [UInt8] = [
        // s0 ACCEPT
        //  cls0 cls1 cls2 cls3 cls4 cls5 cls6 cls7 cls8 cls9 cls10 cls11
            0,   96,  96,  96,  12,  36,  24,  48,  72,  60,  84,   96,
        // s12 — need 1 cont (any)
            96,  0,   0,   0,   96,  96,  96,  96,  96,  96,  96,   96,
        // s24 — need 2 conts (first any)
            96,  12,  12,  12,  96,  96,  96,  96,  96,  96,  96,   96,
        // s36 — E0: first cont must be A0..BF (cls 3)
            96,  96,  96,  12,  96,  96,  96,  96,  96,  96,  96,   96,
        // s48 — ED: first cont must be 80..9F (cls 1 or 2)
            96,  12,  12,  96,  96,  96,  96,  96,  96,  96,  96,   96,
        // s60 — F1..F3: need 3 conts (first any)
            96,  24,  24,  24,  96,  96,  96,  96,  96,  96,  96,   96,
        // s72 — F0: first cont must be 90..BF (cls 2 or 3)
            96,  96,  24,  24,  96,  96,  96,  96,  96,  96,  96,   96,
        // s84 — F4: first cont must be 80..8F (cls 1)
            96,  24,  96,  96,  96,  96,  96,  96,  96,  96,  96,   96,
        // s96 REJECT (terminal)
            96,  96,  96,  96,  96,  96,  96,  96,  96,  96,  96,   96,
    ]

    /// Validate with offset tracking. Returns `.invalid(offset:)` where
    /// `offset` is the index of the first byte of the malformed sequence.
    @usableFromInline
    static func validate(_ bytes: Bytes) -> UTF8Validator.ValidationResult {
        var state: UInt8 = ACCEPT
        var sequenceStart: Int = 0
        var rejectedAt: Int = -1
        let count = bytes.count

        bytes.withUnsafeBytes { src in
            var i = 0
            while i < count {
                let cls = byteClass[Int(src[i])]
                state = transition[Int(state) + Int(cls)]
                if state == REJECT {
                    rejectedAt = sequenceStart
                    return
                }
                if state == ACCEPT {
                    sequenceStart = i + 1
                }
                i += 1
            }
        }

        if rejectedAt >= 0 { return .invalid(offset: rejectedAt) }
        if state != ACCEPT { return .invalid(offset: sequenceStart) }
        return .valid
    }

    /// Fast yes/no validation. Skips the offset bookkeeping.
    @usableFromInline
    static func isValid(_ bytes: Bytes) -> Bool {
        var state: UInt8 = ACCEPT
        let count = bytes.count
        var ok = true

        bytes.withUnsafeBytes { src in
            var i = 0
            while i < count {
                let cls = byteClass[Int(src[i])]
                state = transition[Int(state) + Int(cls)]
                if state == REJECT {
                    ok = false
                    return
                }
                i += 1
            }
        }

        return ok && state == ACCEPT
    }
}
```

Sanity check the byte-class array length: 128 (ASCII) + 16 + 16 + 32 + 2 + 30 + 1 + 12 + 1 + 2 + 1 + 3 + 1 + 11 = 256. ✓

- [ ] **Step 4: Wire up public API**

Replace `Sources/UTF8Validator/UTF8Validator.swift`:
```swift
import Bytes

/// Strict UTF-8 byte-sequence validator (RFC 3629).
public enum UTF8Validator {

    /// Outcome of validating a byte sequence as UTF-8.
    public enum ValidationResult: Equatable, Hashable, Sendable {
        case valid

        /// Validation failed; `offset` is the byte index where the first
        /// malformed sequence began (WHATWG convention).
        case invalid(offset: Int)
    }

    /// Fast yes/no validation. Equivalent to `validate(_:) == .valid`
    /// but allowed to skip offset bookkeeping.
    public static func isValid(_ bytes: Bytes) -> Bool {
        UTF8ValidatorDFA.isValid(bytes)
    }

    /// Validate `bytes` as strict UTF-8 per RFC 3629. Rejects overlongs,
    /// surrogates (U+D800–U+DFFF), and code points > U+10FFFF.
    public static func validate(_ bytes: Bytes) -> ValidationResult {
        UTF8ValidatorDFA.validate(bytes)
    }
}
```

- [ ] **Step 5: Run smoke + result tests**

Run: `swift test --filter UTF8ValidatorTests 2>&1 | tail -10`
Expected: 5 result tests + 5 smoke tests = 10 passing. No warnings.

```bash
swift test 2>&1 | tail -5
```
Expected: full suite green (no regressions).

- [ ] **Step 6: Commit**

```bash
git add Sources/UTF8Validator Tests/UTF8ValidatorTests
git commit -m "$(cat <<'EOF'
feat(utf8-validator): add DFA tables and scalar validator

Two static tables (byte-class lookup and 9×12 transition table)
implementing strict UTF-8 validation per RFC 3629. Public API exposes
isValid and validate entry points.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: ASCII coverage tests

**Files:**
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorASCIITests.swift`

- [ ] **Step 1: Write the tests**

Create `Tests/UTF8ValidatorTests/UTF8ValidatorASCIITests.swift`:
```swift
import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorASCIITests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func everyASCIIByteIsValid() {
        for byte: UInt8 in 0x00 ... 0x7F {
            #expect(UTF8Validator.validate(b([byte])) == .valid,
                    "expected ASCII byte \(byte) to be valid")
            #expect(UTF8Validator.isValid(b([byte])),
                    "expected isValid for ASCII byte \(byte)")
        }
    }

    @Test
    func longASCIIStringIsValid() {
        let kib = Array(repeating: UInt8(0x41), count: 1024)
        #expect(UTF8Validator.validate(b(kib)) == .valid)
        #expect(UTF8Validator.isValid(b(kib)))
    }

    @Test
    func mixedASCIIRoundTrips() {
        let helloWorld: [UInt8] = [
            0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x2C, 0x20,
            0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21,
        ]
        #expect(UTF8Validator.validate(b(helloWorld)) == .valid)
    }
}
```

- [ ] **Step 2: Run**

```bash
swift test --filter UTF8ValidatorASCIITests 2>&1 | tail -10
```
Expected: 3 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/UTF8ValidatorTests/UTF8ValidatorASCIITests.swift
git commit -m "$(cat <<'EOF'
test(utf8-validator): ASCII coverage

Every ASCII byte 0x00-0x7F validated; 1 KiB ASCII string; mixed string.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Multi-byte coverage tests

**Files:**
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorMultiByteTests.swift`

- [ ] **Step 1: Write the tests**

Create `Tests/UTF8ValidatorTests/UTF8ValidatorMultiByteTests.swift`:
```swift
import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorMultiByteTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    // 2-byte sequences

    @Test
    func twoByteLowerBound() {
        // U+0080 = C2 80
        #expect(UTF8Validator.validate(b([0xC2, 0x80])) == .valid)
    }

    @Test
    func twoByteCopyright() {
        // U+00A9 © = C2 A9
        #expect(UTF8Validator.validate(b([0xC2, 0xA9])) == .valid)
    }

    @Test
    func twoByteUpperBound() {
        // U+07FF = DF BF
        #expect(UTF8Validator.validate(b([0xDF, 0xBF])) == .valid)
    }

    // 3-byte sequences

    @Test
    func threeByteLowerBound() {
        // U+0800 = E0 A0 80
        #expect(UTF8Validator.validate(b([0xE0, 0xA0, 0x80])) == .valid)
    }

    @Test
    func threeByteEuro() {
        // U+20AC € = E2 82 AC
        #expect(UTF8Validator.validate(b([0xE2, 0x82, 0xAC])) == .valid)
    }

    @Test
    func threeByteReplacementChar() {
        // U+FFFD = EF BF BD
        #expect(UTF8Validator.validate(b([0xEF, 0xBF, 0xBD])) == .valid)
    }

    @Test
    func threeByteUpperBound() {
        // U+FFFF = EF BF BF
        #expect(UTF8Validator.validate(b([0xEF, 0xBF, 0xBF])) == .valid)
    }

    @Test
    func threeByteJustBeforeSurrogates() {
        // U+D7FF = ED 9F BF
        #expect(UTF8Validator.validate(b([0xED, 0x9F, 0xBF])) == .valid)
    }

    @Test
    func threeByteJustAfterSurrogates() {
        // U+E000 = EE 80 80
        #expect(UTF8Validator.validate(b([0xEE, 0x80, 0x80])) == .valid)
    }

    // 4-byte sequences

    @Test
    func fourByteLowerBound() {
        // U+10000 = F0 90 80 80
        #expect(UTF8Validator.validate(b([0xF0, 0x90, 0x80, 0x80])) == .valid)
    }

    @Test
    func fourByteGrinningFace() {
        // U+1F600 😀 = F0 9F 98 80
        #expect(UTF8Validator.validate(b([0xF0, 0x9F, 0x98, 0x80])) == .valid)
    }

    @Test
    func fourByteUpperBound() {
        // U+10FFFF = F4 8F BF BF
        #expect(UTF8Validator.validate(b([0xF4, 0x8F, 0xBF, 0xBF])) == .valid)
    }

    // Mixed

    @Test
    func interleaved() {
        // "A" + © + € + 😀 = 41 C2 A9 E2 82 AC F0 9F 98 80
        let mixed: [UInt8] = [
            0x41,
            0xC2, 0xA9,
            0xE2, 0x82, 0xAC,
            0xF0, 0x9F, 0x98, 0x80,
        ]
        #expect(UTF8Validator.validate(b(mixed)) == .valid)
    }
}
```

- [ ] **Step 2: Run**

```bash
swift test --filter UTF8ValidatorMultiByteTests 2>&1 | tail -10
```
Expected: 13 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/UTF8ValidatorTests/UTF8ValidatorMultiByteTests.swift
git commit -m "$(cat <<'EOF'
test(utf8-validator): multi-byte well-formed coverage

2/3/4-byte sequences across the valid ranges, including boundary
code points (U+0080, U+07FF, U+0800, U+D7FF, U+E000, U+FFFF,
U+10000, U+10FFFF) and an interleaved example.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Rejection tests

**Files:**
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorRejectionTests.swift`

- [ ] **Step 1: Write the tests**

Create `Tests/UTF8ValidatorTests/UTF8ValidatorRejectionTests.swift`:
```swift
import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorRejectionTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    private func reject(_ xs: [UInt8], _ msg: String) {
        let r = UTF8Validator.validate(b(xs))
        if case .valid = r {
            Issue.record("expected rejection for \(msg) — got .valid")
        }
        #expect(UTF8Validator.isValid(b(xs)) == false,
                "expected isValid==false for \(msg)")
    }

    // Overlongs

    @Test
    func overlongNullTwoByte() { reject([0xC0, 0x80], "U+0000 as 2-byte") }

    @Test
    func overlongNullThreeByte() { reject([0xE0, 0x80, 0x80], "U+0000 as 3-byte") }

    @Test
    func overlongNullFourByte() { reject([0xF0, 0x80, 0x80, 0x80], "U+0000 as 4-byte") }

    @Test
    func overlongDeleteTwoByte() { reject([0xC1, 0xBF], "U+007F as 2-byte") }

    @Test
    func overlong07FFThreeByte() { reject([0xE0, 0x9F, 0xBF], "U+07FF as 3-byte") }

    @Test
    func overlongFFFFFourByte() { reject([0xF0, 0x8F, 0xBF, 0xBF], "U+FFFF as 4-byte") }

    // Surrogates

    @Test
    func surrogateLowerBound() { reject([0xED, 0xA0, 0x80], "U+D800") }

    @Test
    func surrogateMidpoint() { reject([0xED, 0xAA, 0xAA], "U+DAAA") }

    @Test
    func surrogateUpperBound() { reject([0xED, 0xBF, 0xBF], "U+DFFF") }

    // Out of range

    @Test
    func outOfRangeJustAboveMax() { reject([0xF4, 0x90, 0x80, 0x80], "U+110000") }

    @Test
    func fiveByteSequence() { reject([0xF8, 0x87, 0xBF, 0xBF, 0xBF], "5-byte form") }

    @Test
    func sixByteSequence() { reject([0xFC, 0x84, 0x80, 0x80, 0x80, 0x80], "6-byte form") }

    // Invalid lead bytes

    @Test
    func invalidLeadC0() { reject([0xC0], "0xC0 alone") }

    @Test
    func invalidLeadC1() { reject([0xC1], "0xC1 alone") }

    @Test
    func invalidLeadsF5ThroughFF() {
        for byte: UInt8 in 0xF5 ... 0xFF {
            reject([byte], "\(String(byte, radix: 16)) alone")
        }
    }

    // Stray continuations

    @Test
    func strayContinuations() {
        for byte: UInt8 in 0x80 ... 0xBF {
            reject([byte], "stray cont \(String(byte, radix: 16))")
        }
    }

    // Truncated

    @Test
    func truncatedTwoByteLead() { reject([0xC2], "C2 without cont") }

    @Test
    func truncatedThreeByteAfterLead() { reject([0xE2], "E2 alone") }

    @Test
    func truncatedThreeByteAfterOneCont() { reject([0xE2, 0x82], "E2 82 (1 of 2 conts)") }

    @Test
    func truncatedFourByteAfterLead() { reject([0xF0], "F0 alone") }

    @Test
    func truncatedFourByteAfterTwoConts() { reject([0xF0, 0x9F, 0x98], "F0 9F 98 (2 of 3 conts)") }

    // Mid-sequence garbage

    @Test
    func validPrefixBadByteValidSuffix() {
        // ASCII "A", then valid €, then bad C0, then ASCII "B"
        // The validator rejects on the first bad byte.
        let xs: [UInt8] = [
            0x41,                      // A
            0xE2, 0x82, 0xAC,          // €
            0xC0,                       // overlong/invalid lead
            0x42,                       // B
        ]
        let r = UTF8Validator.validate(b(xs))
        if case .valid = r {
            Issue.record("expected rejection")
        }
    }
}
```

- [ ] **Step 2: Run**

```bash
swift test --filter UTF8ValidatorRejectionTests 2>&1 | tail -10
```
Expected: 21 tests pass (the `invalidLeadsF5ThroughFF` and `strayContinuations` tests internally loop).

- [ ] **Step 3: Commit**

```bash
git add Tests/UTF8ValidatorTests/UTF8ValidatorRejectionTests.swift
git commit -m "$(cat <<'EOF'
test(utf8-validator): rejection coverage

Overlongs, surrogates, out-of-range code points, invalid lead bytes,
stray continuations, truncated sequences, mid-sequence garbage.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Offset reporting tests

**Files:**
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorOffsetTests.swift`

- [ ] **Step 1: Write the tests**

Create `Tests/UTF8ValidatorTests/UTF8ValidatorOffsetTests.swift`:
```swift
import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorOffsetTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func badByteAtStartOffsetZero() {
        #expect(UTF8Validator.validate(b([0xFF])) == .invalid(offset: 0))
    }

    @Test
    func badByteAfterASCIIPrefix() {
        // "ABC" + 0xFF — bad byte at index 3
        #expect(UTF8Validator.validate(b([0x41, 0x42, 0x43, 0xFF]))
                == .invalid(offset: 3))
    }

    @Test
    func badContinuationOffsetEqualsLeadIndex() {
        // ASCII "A" then 3-byte lead E2 then bad cont C0
        // The malformed sequence starts at the lead byte (index 1).
        #expect(UTF8Validator.validate(b([0x41, 0xE2, 0xC0]))
                == .invalid(offset: 1))
    }

    @Test
    func truncatedSequenceOffsetIsLeadIndex() {
        // ASCII "AB" then 3-byte lead E2 with no continuations
        // Truncation reported at the lead's index (2).
        #expect(UTF8Validator.validate(b([0x41, 0x42, 0xE2]))
                == .invalid(offset: 2))
    }

    @Test
    func truncatedFourByteOffsetIsLeadIndex() {
        // ASCII "A" then F0 9F (lead + 1 of 3 conts)
        #expect(UTF8Validator.validate(b([0x41, 0xF0, 0x9F]))
                == .invalid(offset: 1))
    }

    @Test
    func strayContinuationOffsetIsItsOwnIndex() {
        // ASCII "AB" then stray 0xBF
        #expect(UTF8Validator.validate(b([0x41, 0x42, 0xBF]))
                == .invalid(offset: 2))
    }

    @Test
    func surrogateOffsetIsLeadIndex() {
        // ASCII "X" then ED A0 80 (surrogate)
        #expect(UTF8Validator.validate(b([0x58, 0xED, 0xA0, 0x80]))
                == .invalid(offset: 1))
    }

    @Test
    func overlongOffsetIsLeadIndex() {
        // ASCII "X" then C0 80 (overlong null)
        // C0 itself is an invalid lead (cls 11), rejected at index 1.
        #expect(UTF8Validator.validate(b([0x58, 0xC0, 0x80]))
                == .invalid(offset: 1))
    }

    @Test
    func multipleValidSequencesThenBadByte() {
        // "A€😀" then 0xFF
        let xs: [UInt8] = [
            0x41,                       // A     (offset 0)
            0xE2, 0x82, 0xAC,           // €     (offsets 1..3)
            0xF0, 0x9F, 0x98, 0x80,     // 😀    (offsets 4..7)
            0xFF,                        // bad  (offset 8)
        ]
        #expect(UTF8Validator.validate(b(xs)) == .invalid(offset: 8))
    }
}
```

- [ ] **Step 2: Run**

```bash
swift test --filter UTF8ValidatorOffsetTests 2>&1 | tail -10
```
Expected: 9 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/UTF8ValidatorTests/UTF8ValidatorOffsetTests.swift
git commit -m "$(cat <<'EOF'
test(utf8-validator): first-invalid-byte offset reporting

Verifies WHATWG offset semantics: malformed-sequence start, not the
specific offending continuation. Covers truncation, surrogates,
overlongs, stray conts, and mid-stream garbage.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Exhaustive round-trip tests

**Files:**
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorExhaustiveTests.swift`

This task runs the validator against every Unicode scalar (~1.1M code points) using a hand-rolled UTF-8 encoder as the independent oracle.

- [ ] **Step 1: Write the tests**

Create `Tests/UTF8ValidatorTests/UTF8ValidatorExhaustiveTests.swift`:
```swift
import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorExhaustiveTests {

    /// Independent hand-rolled UTF-8 encoder used as oracle.
    /// Does NOT depend on Swift's `Unicode.UTF8.encode`.
    private func encode(_ cp: UInt32) -> [UInt8] {
        precondition(cp <= 0x10FFFF)
        if cp < 0x80 {
            return [UInt8(cp)]
        } else if cp < 0x800 {
            return [
                UInt8(0xC0 | (cp >> 6)),
                UInt8(0x80 | (cp & 0x3F)),
            ]
        } else if cp < 0x10000 {
            return [
                UInt8(0xE0 | (cp >> 12)),
                UInt8(0x80 | ((cp >> 6) & 0x3F)),
                UInt8(0x80 | (cp & 0x3F)),
            ]
        } else {
            return [
                UInt8(0xF0 | (cp >> 18)),
                UInt8(0x80 | ((cp >> 12) & 0x3F)),
                UInt8(0x80 | ((cp >> 6) & 0x3F)),
                UInt8(0x80 | (cp & 0x3F)),
            ]
        }
    }

    @Test
    func everyValidCodePointRoundTrips() {
        for cp: UInt32 in 0x0000 ... 0x10FFFF {
            // Skip surrogates — they are not valid Unicode scalars.
            if cp >= 0xD800 && cp <= 0xDFFF { continue }
            let bytes = Bytes(encode(cp))
            let r = UTF8Validator.validate(bytes)
            if r != .valid {
                Issue.record("U+\(String(cp, radix: 16, uppercase: true)) encoded to \(Array(bytes)) was rejected with \(r)")
                return  // stop on first failure to keep output focused
            }
            if !UTF8Validator.isValid(bytes) {
                Issue.record("isValid==false for U+\(String(cp, radix: 16, uppercase: true))")
                return
            }
        }
    }

    @Test
    func everySurrogateEncodingIsRejected() {
        // Encode each surrogate code point as if it were valid and verify
        // the validator rejects it.
        for cp: UInt32 in 0xD800 ... 0xDFFF {
            let bytes = Bytes(encode(cp))
            let r = UTF8Validator.validate(bytes)
            if r == .valid {
                Issue.record("U+\(String(cp, radix: 16, uppercase: true)) (surrogate) was accepted")
                return
            }
        }
    }
}
```

- [ ] **Step 2: Run**

```bash
swift test --filter UTF8ValidatorExhaustiveTests 2>&1 | tail -10
```
Expected: 2 tests pass. If `everyValidCodePointRoundTrips` reports an Issue for a specific code point, that's a real DFA bug — investigate by inspecting the failing encoding and the relevant state transitions.

If runtime is excessive (> 10 s on debug builds), consider adding `swift test -c release` as the verification step.

- [ ] **Step 3: Commit**

```bash
git add Tests/UTF8ValidatorTests/UTF8ValidatorExhaustiveTests.swift
git commit -m "$(cat <<'EOF'
test(utf8-validator): exhaustive round-trip over all Unicode scalars

Hand-rolled UTF-8 encoder as oracle. Validates ~1.1M code points
U+0000-U+10FFFF (excluding surrogates) round-trip to .valid.
Also verifies every surrogate code-point encoding is rejected.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Bytes extensions

**Files:**
- Modify: `Sources/UTF8Validator/UTF8ValidatorExtensions.swift`
- Create: `Tests/UTF8ValidatorTests/UTF8ValidatorExtensionsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UTF8ValidatorTests/UTF8ValidatorExtensionsTests.swift`:
```swift
import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorExtensionsTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func isValidUTF8MatchesNamespaceCall() {
        let valid = b([0x41, 0xC2, 0xA9])
        let invalid = b([0xC0, 0x80])
        #expect(valid.isValidUTF8 == UTF8Validator.isValid(valid))
        #expect(invalid.isValidUTF8 == UTF8Validator.isValid(invalid))
        #expect(valid.isValidUTF8)
        #expect(invalid.isValidUTF8 == false)
    }

    @Test
    func validateUTF8MatchesNamespaceCall() {
        let valid = b([0x41])
        let invalid = b([0x41, 0xFF])
        #expect(valid.validateUTF8() == UTF8Validator.validate(valid))
        #expect(invalid.validateUTF8() == UTF8Validator.validate(invalid))
        #expect(invalid.validateUTF8() == .invalid(offset: 1))
    }

    @Test
    func extensionsOnEmpty() {
        let empty = b([])
        #expect(empty.isValidUTF8)
        #expect(empty.validateUTF8() == .valid)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter UTF8ValidatorExtensionsTests 2>&1 | tail -10
```
Expected: compile error.

- [ ] **Step 3: Implement extensions**

Replace contents of `Sources/UTF8Validator/UTF8ValidatorExtensions.swift`:
```swift
import Bytes

extension Bytes {

    /// `true` iff the bytes are well-formed strict UTF-8.
    public var isValidUTF8: Bool {
        UTF8Validator.isValid(self)
    }

    /// Validate as strict UTF-8; on failure the result carries the
    /// offset of the first byte of the malformed sequence.
    public func validateUTF8() -> UTF8Validator.ValidationResult {
        UTF8Validator.validate(self)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter UTF8ValidatorExtensionsTests 2>&1 | tail -10
```
Expected: 3 tests pass.

```bash
swift test 2>&1 | tail -5
```
Expected: full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/UTF8Validator Tests/UTF8ValidatorTests
git commit -m "$(cat <<'EOF'
feat(utf8-validator): add Bytes extensions

isValidUTF8 and validateUTF8() for ergonomic call sites. Thin wrappers
over the namespace API.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Coverage verification + layer doc update

**Files:**
- Possibly: `Tests/UTF8ValidatorTests/*` (coverage fill-ins, if needed)
- Modify: `layers/layer-01-primitives.md`

- [ ] **Step 1: Run full suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass, zero warnings.

- [ ] **Step 2: Generate coverage**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build' \
  Sources/UTF8Validator/UTF8Validator.swift \
  Sources/UTF8Validator/UTF8ValidatorDFA.swift \
  Sources/UTF8Validator/UTF8ValidatorExtensions.swift
```

Expected: each file ≥ 90% line coverage.

The exhaustive round-trip test alone should give 100% on `UTF8ValidatorDFA.swift`. The other two files are trivial wrappers and should also hit 100%.

If any file falls short, identify uncovered lines via:
```bash
xcrun llvm-cov show "$BIN" -instr-profile="$PROF" \
  Sources/UTF8Validator/<file>.swift | head -100
```

Add targeted tests in the corresponding test file. If lines are genuinely defensive/unreachable (e.g., precondition message autoclosures), prefer dropping the message to fabricating coverage tests.

- [ ] **Step 3: Commit coverage tests if added**

```bash
# Only if Step 2 added tests
git add Tests/UTF8ValidatorTests Sources/UTF8Validator
git commit -m "$(cat <<'EOF'
test(utf8-validator): fill coverage gaps

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Update Layer 1 doc**

Edit `layers/layer-01-primitives.md`. Currently the "shipping modules" list ends with `Sources/COBS/`. Add a new bullet for UTF8Validator and remove SIMD UTF-8 from the remaining-categories line.

Before:
```
> - `Sources/COBS/` — Consistent Overhead Byte Stuffing codec with body-only and auto-terminator framing ([design](../docs/superpowers/specs/2026-05-17-cobs-design.md), [plan](../docs/superpowers/plans/2026-05-17-cobs-module.md))
>
> Remaining categories (SIMD UTF-8, URL/IDNA) pending their own designs.
```

After:
```
> - `Sources/COBS/` — Consistent Overhead Byte Stuffing codec with body-only and auto-terminator framing ([design](../docs/superpowers/specs/2026-05-17-cobs-design.md), [plan](../docs/superpowers/plans/2026-05-17-cobs-module.md))
> - `Sources/UTF8Validator/` — strict UTF-8 byte-sequence validator (RFC 3629) with first-invalid-byte offset reporting; scalar DFA, SIMD fast path deferred ([design](../docs/superpowers/specs/2026-05-18-utf8-validator-design.md), [plan](../docs/superpowers/plans/2026-05-18-utf8-validator-module.md))
>
> Remaining categories (URL/IDNA) pending their own designs.
```

- [ ] **Step 5: Commit**

```bash
git add layers/layer-01-primitives.md
git commit -m "$(cat <<'EOF'
docs(layer-1): mark UTF8Validator module shipped

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** Every API surface item (`isValid`, `validate`, `ValidationResult`, `Bytes.isValidUTF8`, `Bytes.validateUTF8()`) has at least one task. Every test category in the spec (`ASCIITests`, `MultiByteTests`, `RejectionTests`, `OffsetTests`, `ExhaustiveTests`, `ExtensionsTests`) is covered.
- **DFA correctness:** The tables in Task 3 are derived from scratch (not copy-pasted from a third-party source); each row's transitions are documented inline with the byte-class meaning. The exhaustive round-trip in Task 8 is the strongest correctness check — if any of the ~1.1M code points round-trips incorrectly, that's a real DFA bug, not a test bug.
- **No placeholders:** Every step contains either runnable code or an exact command with expected output.
- **Type consistency:** `UTF8Validator.ValidationResult`, `.valid` / `.invalid(offset:)`, and helper signatures match the spec across all tasks.
- **API uncertainty already resolved:** `Bytes` interop (`Bytes(_:)`, `Bytes.withUnsafeBytes`, `Bytes.count`) was used across the COBS module and is known to work.

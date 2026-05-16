# COBS Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `COBS` Layer 1 byte-stuffing codec per the spec at `docs/superpowers/specs/2026-05-17-cobs-design.md`.

**Architecture:** Five source files under `Sources/COBS/` exposing a namespaced `COBS` enum with `encode`/`encoded`/`decode`/`decoded` quartet, a `Framing` enum (`.none` default, `.terminator` opt-in), structured `COBSError`, and `Bytes` extensions. Single-pass O(n) algorithms over `BytesMut`-backed output. Stdlib-only; depends on `Bytes`.

**Tech Stack:** Swift 6 (toolchain ≥ 6.0), SwiftPM, Swift Testing (`import Testing`, `@Test`, `#expect`).

---

## File Structure

**Sources** (`Sources/COBS/`):
- `COBS.swift` — `public enum COBS`, `Framing` nested enum, `maxEncodedSize` / `maxDecodedSize` static helpers
- `COBSError.swift` — `public enum COBSError: Error, Hashable, Sendable`
- `COBSEncode.swift` — `COBS.encode(_:into:framing:)`, `COBS.encoded(_:framing:)`
- `COBSDecode.swift` — `COBS.decode(_:into:framing:)`, `COBS.decoded(_:framing:)`
- `COBSExtensions.swift` — `Bytes.cobsEncoded(framing:)`, `Bytes.init(cobsDecoding:framing:)`

**Tests** (`Tests/COBSTests/`):
- `COBSEncodeTests.swift`
- `COBSDecodeTests.swift`
- `COBSFramingTests.swift`
- `COBSRoundTripTests.swift`
- `COBSErrorTests.swift`
- `COBSExtensionsTests.swift`

---

## Task 1: Package scaffolding

**Files:**
- Modify: `Package.swift`
- Create: `Sources/COBS/COBS.swift` (stub)
- Create: `Sources/COBS/COBSError.swift` (stub)
- Create: `Sources/COBS/COBSEncode.swift` (stub)
- Create: `Sources/COBS/COBSDecode.swift` (stub)
- Create: `Sources/COBS/COBSExtensions.swift` (stub)
- Create: `Tests/COBSTests/COBSScaffoldTests.swift` (stub — replaced by real test files later)

- [ ] **Step 1: Add COBS product + target to Package.swift**

Add to `products:` array (after BitSet line):
```swift
.library(name: "COBS", targets: ["COBS"]),
```

Add to `targets:` array (after BitSet entries):
```swift
.target(name: "COBS", dependencies: ["Bytes"], path: "Sources/COBS"),
.testTarget(name: "COBSTests", dependencies: ["COBS", "Bytes"], path: "Tests/COBSTests"),
```

- [ ] **Step 2: Create stub source files**

`Sources/COBS/COBS.swift`:
```swift
import Bytes

/// Consistent Overhead Byte Stuffing (COBS) codec namespace.
public enum COBS {
}
```

`Sources/COBS/COBSError.swift`:
```swift
public enum COBSError: Error, Hashable, Sendable {
}
```

`Sources/COBS/COBSEncode.swift`:
```swift
import Bytes
```

`Sources/COBS/COBSDecode.swift`:
```swift
import Bytes
```

`Sources/COBS/COBSExtensions.swift`:
```swift
import Bytes
```

- [ ] **Step 3: Create stub test file**

`Tests/COBSTests/COBSScaffoldTests.swift`:
```swift
import Testing
import COBS

@Test
func scaffoldCompiles() {
    // Placeholder; real tests replace this in subsequent tasks.
    #expect(Bool(true))
}
```

- [ ] **Step 4: Build & test to verify scaffolding**

Run: `swift build`
Expected: builds cleanly, no warnings.

Run: `swift test --filter COBSTests`
Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/COBS Tests/COBSTests
git commit -m "$(cat <<'EOF'
feat(cobs): scaffold COBS module

Add library product, source target, and test target with stub files.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: COBSError type

**Files:**
- Modify: `Sources/COBS/COBSError.swift`
- Create: `Tests/COBSTests/COBSErrorTests.swift`

- [ ] **Step 1: Write the failing test file**

`Tests/COBSTests/COBSErrorTests.swift`:
```swift
import Testing
import COBS

@Suite
struct COBSErrorTests {

    @Test
    func invalidZeroByteCarriesOffset() {
        let e = COBSError.invalidZeroByte(offset: 7)
        if case .invalidZeroByte(let o) = e {
            #expect(o == 7)
        } else {
            Issue.record("expected .invalidZeroByte case")
        }
    }

    @Test
    func unexpectedTerminatorCarriesOffset() {
        let e = COBSError.unexpectedTerminator(offset: 3)
        if case .unexpectedTerminator(let o) = e {
            #expect(o == 3)
        } else {
            Issue.record("expected .unexpectedTerminator case")
        }
    }

    @Test
    func truncatedAndMissingTerminatorAreConstructible() {
        let _ = COBSError.truncated
        let _ = COBSError.missingTerminator
    }

    @Test
    func equalCasesHashEqual() {
        #expect(COBSError.truncated == COBSError.truncated)
        #expect(COBSError.missingTerminator == COBSError.missingTerminator)
        #expect(COBSError.invalidZeroByte(offset: 5)
                == COBSError.invalidZeroByte(offset: 5))
        #expect(COBSError.unexpectedTerminator(offset: 2)
                == COBSError.unexpectedTerminator(offset: 2))
    }

    @Test
    func distinctCasesAreUnequal() {
        #expect(COBSError.truncated != COBSError.missingTerminator)
        #expect(COBSError.invalidZeroByte(offset: 1)
                != COBSError.invalidZeroByte(offset: 2))
        #expect(COBSError.unexpectedTerminator(offset: 1)
                != COBSError.truncated)
    }

    @Test
    func hashableUsableInSet() {
        var s = Set<COBSError>()
        s.insert(.truncated)
        s.insert(.truncated)
        s.insert(.invalidZeroByte(offset: 1))
        s.insert(.invalidZeroByte(offset: 1))
        s.insert(.invalidZeroByte(offset: 2))
        #expect(s.count == 3)
    }

    @Test
    func errorIsSendable() {
        // Compile-time check: send across actor boundary.
        let e: COBSError = .truncated
        Task.detached { @Sendable in
            let _ = e
        }
    }
}
```

- [ ] **Step 2: Delete the scaffold test and run to verify failure**

```bash
rm Tests/COBSTests/COBSScaffoldTests.swift
swift test --filter COBSTests 2>&1 | head -40
```

Expected: compile error — `COBSError` has no cases.

- [ ] **Step 3: Implement COBSError**

Replace `Sources/COBS/COBSError.swift`:
```swift
/// Errors thrown by `COBS.decode` and friends.
public enum COBSError: Error, Hashable, Sendable {
    /// A 0x00 byte appeared inside encoded payload at `offset`
    /// (only emitted in `.none` framing — 0x00 is invalid in body bytes).
    case invalidZeroByte(offset: Int)

    /// A code byte points past the end of input.
    case truncated

    /// `.terminator` framing but no trailing 0x00 found.
    case missingTerminator

    /// `.terminator` framing but a 0x00 appeared before the final
    /// terminator position (i.e., mid-stream).
    case unexpectedTerminator(offset: Int)
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter COBSTests`
Expected: all `COBSErrorTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/COBS/COBSError.swift Tests/COBSTests
git commit -m "$(cat <<'EOF'
feat(cobs): add COBSError type

Four cases distinguishing body-zero, truncation, missing-terminator,
and unexpected-terminator failures. Hashable and Sendable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Framing enum + size helpers

**Files:**
- Modify: `Sources/COBS/COBS.swift`
- Create: `Tests/COBSTests/COBSSizingTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/COBSTests/COBSSizingTests.swift`:
```swift
import Testing
import COBS

@Suite
struct COBSSizingTests {

    @Test
    func framingHasNoneAndTerminator() {
        let a: COBS.Framing = .none
        let b: COBS.Framing = .terminator
        #expect(a != b)
        #expect(a == .none)
        #expect(b == .terminator)
    }

    @Test
    func framingIsSendableAndHashable() {
        var s = Set<COBS.Framing>()
        s.insert(.none)
        s.insert(.none)
        s.insert(.terminator)
        #expect(s.count == 2)
    }

    @Test
    func maxEncodedSizeEmptyBodyOnly() {
        // Empty encodes to [0x01].
        #expect(COBS.maxEncodedSize(forSourceCount: 0) == 1)
    }

    @Test
    func maxEncodedSizeEmptyTerminator() {
        // Empty encodes to [0x01, 0x00].
        #expect(COBS.maxEncodedSize(forSourceCount: 0, framing: .terminator) == 2)
    }

    @Test
    func maxEncodedSizeBodyOnlySmall() {
        // 1 byte: code(1) + 1 body = 2.
        #expect(COBS.maxEncodedSize(forSourceCount: 1) == 2)
        // 253 bytes: code(1) + 253 body = 254. ⌈253/254⌉ = 1. 253 + 1 + 1 = 255. Wait, formula is n + ⌈n/254⌉ + 1.
        // For n=253: 253 + ⌈253/254⌉(=1) + 1 = 255. (Upper bound — actual is 254.)
        #expect(COBS.maxEncodedSize(forSourceCount: 253) == 255)
    }

    @Test
    func maxEncodedSizeBoundaryAt254() {
        // n=254: 254 + ⌈254/254⌉(=1) + 1 = 256. (Tight — actual is 256.)
        #expect(COBS.maxEncodedSize(forSourceCount: 254) == 256)
    }

    @Test
    func maxEncodedSizeBoundaryAt255() {
        // n=255: 255 + ⌈255/254⌉(=2) + 1 = 258. (Upper bound — actual is 257.)
        #expect(COBS.maxEncodedSize(forSourceCount: 255) == 258)
    }

    @Test
    func maxEncodedSizeTerminatorAdds1() {
        let bodyOnly = COBS.maxEncodedSize(forSourceCount: 254)
        let framed   = COBS.maxEncodedSize(forSourceCount: 254, framing: .terminator)
        #expect(framed == bodyOnly + 1)
    }

    @Test
    func maxDecodedSizeBodyOnly() {
        #expect(COBS.maxDecodedSize(forEncodedCount: 0) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 1) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 5) == 4)
    }

    @Test
    func maxDecodedSizeTerminator() {
        #expect(COBS.maxDecodedSize(forEncodedCount: 0, framing: .terminator) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 1, framing: .terminator) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 2, framing: .terminator) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 5, framing: .terminator) == 3)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter COBSTests` 
Expected: compile error — `COBS.Framing` and the size helpers don't exist.

- [ ] **Step 3: Implement Framing + size helpers**

Replace `Sources/COBS/COBS.swift`:
```swift
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
        precondition(n >= 0, "source count must be non-negative")
        let overhead = (n + 253) / 254  // ⌈n/254⌉, safe for n>=0
        let body = n + overhead + 1
        return framing == .terminator ? body + 1 : body
    }

    /// Upper bound on decoded size: `max(0, n - 1)` body bytes
    /// (`max(0, n - 2)` if framed). Actual decoded size ≤ this.
    public static func maxDecodedSize(forEncodedCount n: Int,
                                      framing: Framing = .none) -> Int {
        precondition(n >= 0, "encoded count must be non-negative")
        let strip = framing == .terminator ? 2 : 1
        return Swift.max(0, n - strip)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter COBSTests`
Expected: all `COBSSizingTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/COBS/COBS.swift Tests/COBSTests/COBSSizingTests.swift
git commit -m "$(cat <<'EOF'
feat(cobs): add Framing enum and size-hint helpers

Framing distinguishes body-only (.none) from auto-terminator (.terminator).
maxEncodedSize / maxDecodedSize let callers pre-reserve BytesMut capacity.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: encode + encoded

**Files:**
- Modify: `Sources/COBS/COBSEncode.swift`
- Create: `Tests/COBSTests/COBSEncodeTests.swift`

Note on BytesMut API: tasks below assume `BytesMut.append(_ byte: UInt8)` exists. Verify by reading `Sources/Bytes/BytesMut.swift`; if the spelling differs (e.g., `putUInt8`, `append(byte:)`), substitute the actual API consistently throughout this task.

- [ ] **Step 1: Verify BytesMut byte-append + mutable-index APIs**

Run: `grep -nE 'public (func|mutating func) (append|put|subscript)' Sources/Bytes/BytesMut.swift`
Expected: lists the available append/subscript/mutating-write APIs.

If the API is `BytesMut.append(_ byte: UInt8)`, use as written. If it's `BytesMut.append(byte:)` or `BytesMut.putUInt8(_:)`, substitute throughout. Likewise verify how to read/overwrite a previously-written byte (e.g., `withUnsafeMutableBytes`, mutable subscript).

For the encoder we need:
- Append a byte (the placeholder, then content bytes).
- Overwrite a previously-appended byte at a known offset (the code-byte placeholder, once the block ends).

Pick the matching idioms before writing code.

- [ ] **Step 2: Write the failing tests**

`Tests/COBSTests/COBSEncodeTests.swift`:
```swift
import Testing
import COBS
import Bytes

@Suite
struct COBSEncodeTests {

    // Helper: build Bytes from a byte literal array.
    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func emptyEncodesToSingleCodeByte() {
        let out = COBS.encoded(b([]))
        #expect(Array(out) == [0x01])
    }

    @Test
    func singleZeroEncodes() {
        let out = COBS.encoded(b([0x00]))
        #expect(Array(out) == [0x01, 0x01])
    }

    @Test
    func twoZerosEncode() {
        let out = COBS.encoded(b([0x00, 0x00]))
        #expect(Array(out) == [0x01, 0x01, 0x01])
    }

    @Test
    func singleNonZeroEncodes() {
        let out = COBS.encoded(b([0x42]))
        #expect(Array(out) == [0x02, 0x42])
    }

    @Test
    func paperExampleEncodes() {
        // [11 22 00 33] -> [03 11 22 02 33]
        let out = COBS.encoded(b([0x11, 0x22, 0x00, 0x33]))
        #expect(Array(out) == [0x03, 0x11, 0x22, 0x02, 0x33])
    }

    @Test
    func longerMixedEncodes() {
        // [00 11 00 00 22 33] -> [01 02 11 01 03 22 33]
        let out = COBS.encoded(b([0x00, 0x11, 0x00, 0x00, 0x22, 0x33]))
        #expect(Array(out) == [0x01, 0x02, 0x11, 0x01, 0x03, 0x22, 0x33])
    }

    @Test
    func twoHundredFiftyFourNonZeroHitsBlockMax() {
        // 254 non-zero bytes -> [FF, 01..01, 01] = 256 bytes total.
        let input = Bytes(Array(repeating: UInt8(0x01), count: 254))
        let out = Array(COBS.encoded(input))
        #expect(out.count == 256)
        #expect(out.first == 0xFF)
        #expect(Array(out[1..<255]) == Array(repeating: UInt8(0x01), count: 254))
        #expect(out.last == 0x01)
    }

    @Test
    func twoHundredFiftyFiveNonZeroSplitsBlocks() {
        // 255 non-zero bytes -> [FF, 01..01(254), 02, 01] = 257 bytes total.
        let input = Bytes(Array(repeating: UInt8(0x01), count: 255))
        let out = Array(COBS.encoded(input))
        #expect(out.count == 257)
        #expect(out[0] == 0xFF)
        #expect(out[255] == 0x02)
        #expect(out[256] == 0x01)
    }

    @Test
    func twoHundredFiftyFourZeros() {
        // 254 zeros -> 255 bytes of 0x01.
        let input = Bytes(Array(repeating: UInt8(0x00), count: 254))
        let out = Array(COBS.encoded(input))
        #expect(out == Array(repeating: UInt8(0x01), count: 255))
    }

    @Test
    func terminatorFramingAppendsZero() {
        let out = COBS.encoded(b([0x11, 0x22]), framing: .terminator)
        // body-only would be [03 11 22]; framed adds trailing 00
        #expect(Array(out) == [0x03, 0x11, 0x22, 0x00])
    }

    @Test
    func terminatorFramingOnEmpty() {
        let out = COBS.encoded(b([]), framing: .terminator)
        #expect(Array(out) == [0x01, 0x00])
    }

    @Test
    func encodeAppendsToExistingBytesMut() {
        var dst = BytesMut()
        dst.append(0xAA)
        dst.append(0xBB)
        let n = COBS.encode(b([0x11, 0x22]), into: &dst)
        let arr = Array(Bytes(dst))
        #expect(arr.prefix(2) == [0xAA, 0xBB])
        #expect(Array(arr.suffix(arr.count - 2)) == [0x03, 0x11, 0x22])
        #expect(n == 3)
    }

    @Test
    func encodeReturnsAppendedCountWithTerminator() {
        var dst = BytesMut()
        let n = COBS.encode(b([]), into: &dst, framing: .terminator)
        #expect(n == 2)
        #expect(Array(Bytes(dst)) == [0x01, 0x00])
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter COBSEncodeTests`
Expected: compile error — `COBS.encode` / `COBS.encoded` don't exist.

- [ ] **Step 4: Implement encode**

Replace `Sources/COBS/COBSEncode.swift`. The implementation below uses a local `[UInt8]` scratch buffer to make the in-place code-byte patching simple, then copies into the destination `BytesMut`. This trades one extra allocation for clear bounds; benchmark-driven inlining is a future concern (deferred in spec §Non-Goals).

```swift
import Bytes

extension COBS {

    /// Encode `input` into `out`. Returns number of bytes appended.
    @discardableResult
    public static func encode(_ input: Bytes,
                              into out: inout BytesMut,
                              framing: Framing = .none) -> Int {
        let encoded = _encode(input, framing: framing)
        let before = out.count
        for byte in encoded {
            out.append(byte)
        }
        return out.count - before
    }

    /// Encode `input` and return a fresh `Bytes`.
    public static func encoded(_ input: Bytes,
                               framing: Framing = .none) -> Bytes {
        Bytes(_encode(input, framing: framing))
    }

    // MARK: - Internal

    private static func _encode(_ input: Bytes, framing: Framing) -> [UInt8] {
        // Reserve worst-case capacity to avoid mid-loop reallocation.
        var out: [UInt8] = []
        out.reserveCapacity(maxEncodedSize(forSourceCount: input.count,
                                           framing: framing))

        // Special case: empty input -> single code byte 0x01.
        if input.isEmpty {
            out.append(0x01)
            if framing == .terminator { out.append(0x00) }
            return out
        }

        var codePos = 0
        out.append(0x00)        // placeholder for first code byte
        var code: UInt8 = 1     // count of bytes in current block + 1

        input.withUnsafeBytes { src in
            for b in src {
                if b == 0x00 {
                    out[codePos] = code
                    codePos = out.count
                    out.append(0x00)
                    code = 1
                } else {
                    out.append(b)
                    code &+= 1
                    if code == 0xFF {
                        out[codePos] = code
                        codePos = out.count
                        out.append(0x00)
                        code = 1
                    }
                }
            }
        }
        out[codePos] = code

        if framing == .terminator { out.append(0x00) }
        return out
    }
}
```

- [ ] **Step 5: Run encode tests**

Run: `swift test --filter COBSEncodeTests`
Expected: all `COBSEncodeTests` pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/COBS/COBSEncode.swift Tests/COBSTests/COBSEncodeTests.swift
git commit -m "$(cat <<'EOF'
feat(cobs): implement encode and encoded

Single-pass O(n) encoder with block-max boundary handling at 254
non-zero bytes. Supports body-only and terminator framing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: decode + decoded

**Files:**
- Modify: `Sources/COBS/COBSDecode.swift`
- Create: `Tests/COBSTests/COBSDecodeTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/COBSTests/COBSDecodeTests.swift`:
```swift
import Testing
import COBS
import Bytes

@Suite
struct COBSDecodeTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func decodeSingleCodeByteYieldsEmpty() throws {
        let out = try COBS.decoded(b([0x01]))
        #expect(Array(out) == [])
    }

    @Test
    func decodeSingleZero() throws {
        let out = try COBS.decoded(b([0x01, 0x01]))
        #expect(Array(out) == [0x00])
    }

    @Test
    func decodeTwoZeros() throws {
        let out = try COBS.decoded(b([0x01, 0x01, 0x01]))
        #expect(Array(out) == [0x00, 0x00])
    }

    @Test
    func decodeSingleNonZero() throws {
        let out = try COBS.decoded(b([0x02, 0x42]))
        #expect(Array(out) == [0x42])
    }

    @Test
    func decodePaperExample() throws {
        let out = try COBS.decoded(b([0x03, 0x11, 0x22, 0x02, 0x33]))
        #expect(Array(out) == [0x11, 0x22, 0x00, 0x33])
    }

    @Test
    func decodeLongerMixed() throws {
        let out = try COBS.decoded(b([0x01, 0x02, 0x11, 0x01, 0x03, 0x22, 0x33]))
        #expect(Array(out) == [0x00, 0x11, 0x00, 0x00, 0x22, 0x33])
    }

    @Test
    func decodeBlockMaxBoundary() throws {
        // 254 non-zero bytes encoded form.
        var encoded: [UInt8] = [0xFF]
        encoded.append(contentsOf: Array(repeating: UInt8(0x01), count: 254))
        encoded.append(0x01)
        let out = try COBS.decoded(b(encoded))
        #expect(Array(out) == Array(repeating: UInt8(0x01), count: 254))
    }

    @Test
    func decodeJustOverBlockMax() throws {
        // 255 non-zero bytes encoded form.
        var encoded: [UInt8] = [0xFF]
        encoded.append(contentsOf: Array(repeating: UInt8(0x01), count: 254))
        encoded.append(0x02)
        encoded.append(0x01)
        let out = try COBS.decoded(b(encoded))
        #expect(Array(out) == Array(repeating: UInt8(0x01), count: 255))
    }

    @Test
    func emptyInputIsTruncated() {
        #expect(throws: COBSError.truncated) {
            _ = try COBS.decoded(b([]))
        }
    }

    @Test
    func codeByteOverrunsInputIsTruncated() {
        // code=5 but only 3 bytes follow
        #expect(throws: COBSError.truncated) {
            _ = try COBS.decoded(b([0x05, 0x11, 0x22, 0x33]))
        }
    }

    @Test
    func zeroInBodyIsInvalidZeroByte() {
        // First byte 0x00 in body-only mode: offset 0.
        #expect {
            try COBS.decoded(b([0x00]))
        } throws: { error in
            guard let e = error as? COBSError,
                  case .invalidZeroByte(let off) = e else { return false }
            return off == 0
        }
    }

    @Test
    func zeroInsideBlockIsInvalidZeroByte() {
        // [03 11 00 33] — 0x00 at offset 2 inside a block.
        #expect {
            try COBS.decoded(b([0x03, 0x11, 0x00, 0x33]))
        } throws: { error in
            guard let e = error as? COBSError,
                  case .invalidZeroByte(let off) = e else { return false }
            return off == 2
        }
    }

    @Test
    func decodeAppendsToExistingBytesMut() throws {
        var dst = BytesMut()
        dst.append(0xAA)
        let n = try COBS.decode(b([0x03, 0x11, 0x22]), into: &dst)
        #expect(n == 2)
        #expect(Array(Bytes(dst)) == [0xAA, 0x11, 0x22])
    }

    @Test
    func decodeReturnsZeroForEmptyEncoding() throws {
        var dst = BytesMut()
        let n = try COBS.decode(b([0x01]), into: &dst)
        #expect(n == 0)
        #expect(Bytes(dst).count == 0)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter COBSDecodeTests`
Expected: compile error — `COBS.decode` / `COBS.decoded` don't exist.

- [ ] **Step 3: Implement decode**

Replace `Sources/COBS/COBSDecode.swift`:
```swift
import Bytes

extension COBS {

    /// Decode `input` into `out`. Returns number of bytes appended.
    /// Throws `COBSError` on malformed input.
    @discardableResult
    public static func decode(_ input: Bytes,
                              into out: inout BytesMut,
                              framing: Framing = .none) throws -> Int {
        let decoded = try _decode(input, framing: framing)
        let before = out.count
        for byte in decoded {
            out.append(byte)
        }
        return out.count - before
    }

    /// Decode `input` and return a fresh `Bytes`.
    public static func decoded(_ input: Bytes,
                               framing: Framing = .none) throws -> Bytes {
        Bytes(try _decode(input, framing: framing))
    }

    // MARK: - Internal

    private static func _decode(_ input: Bytes, framing: Framing) throws -> [UInt8] {

        var payloadCount: Int
        let payloadBase: Int
        if framing == .terminator {
            // Need: input non-empty AND last byte == 0x00.
            if input.isEmpty {
                throw COBSError.missingTerminator
            }
            var lastByte: UInt8 = 0
            input.withUnsafeBytes { src in
                lastByte = src[input.count - 1]
            }
            if lastByte != 0x00 {
                throw COBSError.missingTerminator
            }
            payloadCount = input.count - 1
            payloadBase = 0
        } else {
            payloadCount = input.count
            payloadBase = 0
        }

        if payloadCount == 0 {
            throw COBSError.truncated
        }

        var out: [UInt8] = []
        out.reserveCapacity(maxDecodedSize(forEncodedCount: input.count,
                                            framing: framing))

        var caughtError: COBSError? = nil

        input.withUnsafeBytes { src in
            var i = 0
            while i < payloadCount {
                let code = src[payloadBase + i]
                if code == 0x00 {
                    caughtError = framing == .terminator
                        ? .unexpectedTerminator(offset: i)
                        : .invalidZeroByte(offset: i)
                    return
                }
                i += 1
                let blockEnd = i + Int(code) - 1
                if blockEnd > payloadCount {
                    caughtError = .truncated
                    return
                }
                while i < blockEnd {
                    let bb = src[payloadBase + i]
                    if bb == 0x00 {
                        caughtError = framing == .terminator
                            ? .unexpectedTerminator(offset: i)
                            : .invalidZeroByte(offset: i)
                        return
                    }
                    out.append(bb)
                    i += 1
                }
                // Inter-block zero, unless block was maximal or we've consumed all input.
                if code < 0xFF && i < payloadCount {
                    out.append(0x00)
                }
            }
        }

        if let err = caughtError { throw err }
        return out
    }
}
```

- [ ] **Step 4: Run decode tests**

Run: `swift test --filter COBSDecodeTests`
Expected: all `COBSDecodeTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/COBS/COBSDecode.swift Tests/COBSTests/COBSDecodeTests.swift
git commit -m "$(cat <<'EOF'
feat(cobs): implement decode and decoded

Single-pass O(n) decoder with bounds-checked block reads. Distinguishes
invalidZeroByte, truncated, and (framing-dependent) terminator errors.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Framing-specific tests

**Files:**
- Create: `Tests/COBSTests/COBSFramingTests.swift`

- [ ] **Step 1: Write the tests**

`Tests/COBSTests/COBSFramingTests.swift`:
```swift
import Testing
import COBS
import Bytes

@Suite
struct COBSFramingTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func terminatorEncodeAppendsZero() {
        let out = COBS.encoded(b([0x11, 0x22]), framing: .terminator)
        #expect(Array(out).last == 0x00)
    }

    @Test
    func terminatorDecodeStripsZero() throws {
        let out = try COBS.decoded(b([0x03, 0x11, 0x22, 0x00]), framing: .terminator)
        #expect(Array(out) == [0x11, 0x22])
    }

    @Test
    func terminatorDecodeMissingFinalZero() {
        // Last byte 0x33 != 0x00.
        #expect(throws: COBSError.missingTerminator) {
            _ = try COBS.decoded(b([0x03, 0x11, 0x22, 0x33]), framing: .terminator)
        }
    }

    @Test
    func terminatorDecodeEmptyInputMissingTerminator() {
        #expect(throws: COBSError.missingTerminator) {
            _ = try COBS.decoded(b([]), framing: .terminator)
        }
    }

    @Test
    func terminatorDecodeMidStreamZeroIsUnexpected() {
        // [01 00 01 00] — second-to-last 0x00 occurs as a code byte mid-payload.
        // After stripping trailing 0x00, payload = [01 00 01], i=0 code=1 block end 1, no body,
        // i=1 code=0x00 -> unexpectedTerminator at offset 1.
        #expect {
            try COBS.decoded(b([0x01, 0x00, 0x01, 0x00]), framing: .terminator)
        } throws: { error in
            guard let e = error as? COBSError,
                  case .unexpectedTerminator(let off) = e else { return false }
            return off == 1
        }
    }

    @Test
    func emptyRoundTripFramed() throws {
        let enc = COBS.encoded(b([]), framing: .terminator)
        #expect(Array(enc) == [0x01, 0x00])
        let dec = try COBS.decoded(enc, framing: .terminator)
        #expect(Array(dec) == [])
    }

    @Test
    func framedRoundTripWithEmbeddedZeros() throws {
        let input = b([0x00, 0x11, 0x00, 0x22, 0x33, 0x00])
        let enc = COBS.encoded(input, framing: .terminator)
        #expect(Array(enc).last == 0x00)
        let dec = try COBS.decoded(enc, framing: .terminator)
        #expect(Array(dec) == Array(input))
    }
}
```

- [ ] **Step 2: Run tests**

Run: `swift test --filter COBSFramingTests`
Expected: all `COBSFramingTests` pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/COBSTests/COBSFramingTests.swift
git commit -m "$(cat <<'EOF'
test(cobs): add framing-mode coverage

Verifies terminator-framing encode/decode edges: missing terminator,
mid-stream zeros, empty round-trip.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Round-trip property tests

**Files:**
- Create: `Tests/COBSTests/COBSRoundTripTests.swift`

- [ ] **Step 1: Write the tests**

`Tests/COBSTests/COBSRoundTripTests.swift`:
```swift
import Testing
import COBS
import Bytes

@Suite
struct COBSRoundTripTests {

    /// Seeded linear-congruential generator (no Foundation dependency).
    private struct LCG {
        var state: UInt64
        mutating func next() -> UInt8 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return UInt8(truncatingIfNeeded: state >> 56)
        }
        mutating func bytes(_ n: Int) -> [UInt8] {
            var out: [UInt8] = []
            out.reserveCapacity(n)
            for _ in 0..<n { out.append(next()) }
            return out
        }
    }

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    private func roundTrip(_ input: [UInt8], framing: COBS.Framing) throws {
        let enc = COBS.encoded(b(input), framing: framing)
        let dec = try COBS.decoded(enc, framing: framing)
        #expect(Array(dec) == input,
                "round-trip mismatch (framing: \(framing), n=\(input.count))")
    }

    @Test
    func corpusBodyOnly() throws {
        let corpus: [[UInt8]] = [
            [],
            [0x00],
            [0x01],
            [0xFF],
            [0x00, 0x00],
            [0x11, 0x22, 0x00, 0x33],
            Array(repeating: 0x00, count: 10),
            Array(repeating: 0xAA, count: 10),
            [0x00, 0x01, 0x02, 0x00, 0x03],
        ]
        for input in corpus {
            try roundTrip(input, framing: .none)
        }
    }

    @Test
    func corpusFramed() throws {
        let corpus: [[UInt8]] = [
            [],
            [0x00],
            [0x01],
            [0xFF],
            [0x00, 0x00],
            [0x11, 0x22, 0x00, 0x33],
            Array(repeating: 0x00, count: 10),
            Array(repeating: 0xAA, count: 10),
            [0x00, 0x01, 0x02, 0x00, 0x03],
        ]
        for input in corpus {
            try roundTrip(input, framing: .terminator)
        }
    }

    @Test
    func everySingleByteRoundTripsBodyOnly() throws {
        for byte in UInt8.min ... UInt8.max {
            try roundTrip([byte], framing: .none)
        }
    }

    @Test
    func everySingleByteRoundTripsFramed() throws {
        for byte in UInt8.min ... UInt8.max {
            try roundTrip([byte], framing: .terminator)
        }
    }

    @Test
    func blockBoundaryLengthsRoundTrip() throws {
        let lengths = [253, 254, 255, 256, 507, 508, 509, 510]
        for n in lengths {
            // All non-zero (worst-case for block-max boundary).
            try roundTrip(Array(repeating: UInt8(0x01), count: n), framing: .none)
            try roundTrip(Array(repeating: UInt8(0x01), count: n), framing: .terminator)
            // All zero (worst-case overhead).
            try roundTrip(Array(repeating: UInt8(0x00), count: n), framing: .none)
            try roundTrip(Array(repeating: UInt8(0x00), count: n), framing: .terminator)
        }
    }

    @Test
    func pseudoRandom1KiBRoundTrips() throws {
        var rng = LCG(state: 0xDEAD_BEEF_CAFE_F00D)
        let data = rng.bytes(1024)
        try roundTrip(data, framing: .none)
        try roundTrip(data, framing: .terminator)
    }

    @Test
    func pseudoRandom10KiBRoundTrips() throws {
        var rng = LCG(state: 0x0123_4567_89AB_CDEF)
        let data = rng.bytes(10 * 1024)
        try roundTrip(data, framing: .none)
        try roundTrip(data, framing: .terminator)
    }

    @Test
    func decodedSizeWithinMaxBound() throws {
        var rng = LCG(state: 0xAAAA_5555_BBBB_CCCC)
        let data = rng.bytes(2048)
        let enc = COBS.encoded(b(data))
        let dec = try COBS.decoded(enc)
        let bound = COBS.maxDecodedSize(forEncodedCount: enc.count)
        #expect(dec.count <= bound)
        #expect(dec.count == data.count)
    }
}
```

- [ ] **Step 2: Run tests**

Run: `swift test --filter COBSRoundTripTests`
Expected: all `COBSRoundTripTests` pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/COBSTests/COBSRoundTripTests.swift
git commit -m "$(cat <<'EOF'
test(cobs): add round-trip property coverage

Corpus, every-single-byte, block-boundary lengths, 1 KiB and 10 KiB
pseudo-random sequences. Verifies decoded size stays within
maxDecodedSize bound.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Bytes extensions

**Files:**
- Modify: `Sources/COBS/COBSExtensions.swift`
- Create: `Tests/COBSTests/COBSExtensionsTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/COBSTests/COBSExtensionsTests.swift`:
```swift
import Testing
import COBS
import Bytes

@Suite
struct COBSExtensionsTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func cobsEncodedMatchesNamespaceCall() {
        let input = b([0x11, 0x22, 0x00, 0x33])
        let viaExt = input.cobsEncoded()
        let viaNS  = COBS.encoded(input)
        #expect(Array(viaExt) == Array(viaNS))
    }

    @Test
    func cobsEncodedTerminatorMatchesNamespace() {
        let input = b([0x00, 0xFF, 0x00])
        let viaExt = input.cobsEncoded(framing: .terminator)
        let viaNS  = COBS.encoded(input, framing: .terminator)
        #expect(Array(viaExt) == Array(viaNS))
    }

    @Test
    func bytesInitDecodingMatchesNamespace() throws {
        let encoded = b([0x03, 0x11, 0x22, 0x02, 0x33])
        let viaInit = try Bytes(cobsDecoding: encoded)
        let viaNS   = try COBS.decoded(encoded)
        #expect(Array(viaInit) == Array(viaNS))
    }

    @Test
    func bytesInitDecodingTerminatorMatchesNamespace() throws {
        let encoded = b([0x03, 0x11, 0x22, 0x00])
        let viaInit = try Bytes(cobsDecoding: encoded, framing: .terminator)
        let viaNS   = try COBS.decoded(encoded, framing: .terminator)
        #expect(Array(viaInit) == Array(viaNS))
    }

    @Test
    func roundTripThroughExtensions() throws {
        let input = b([0x00, 0x11, 0x22, 0x00, 0x33, 0xFF, 0x00])
        let enc = input.cobsEncoded(framing: .terminator)
        let dec = try Bytes(cobsDecoding: enc, framing: .terminator)
        #expect(Array(dec) == Array(input))
    }

    @Test
    func bytesInitDecodingPropagatesError() {
        #expect(throws: COBSError.truncated) {
            _ = try Bytes(cobsDecoding: b([]))
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter COBSExtensionsTests`
Expected: compile error — `Bytes.cobsEncoded` / `Bytes.init(cobsDecoding:)` don't exist.

- [ ] **Step 3: Implement extensions**

Replace `Sources/COBS/COBSExtensions.swift`:
```swift
import Bytes

extension Bytes {

    /// COBS-encode these bytes.
    public func cobsEncoded(framing: COBS.Framing = .none) -> Bytes {
        COBS.encoded(self, framing: framing)
    }

    /// Initialize from a COBS-encoded source. Throws `COBSError` on malformed input.
    public init(cobsDecoding source: Bytes,
                framing: COBS.Framing = .none) throws {
        self = try COBS.decoded(source, framing: framing)
    }
}
```

- [ ] **Step 4: Run extension tests**

Run: `swift test --filter COBSExtensionsTests`
Expected: all `COBSExtensionsTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/COBS/COBSExtensions.swift Tests/COBSTests/COBSExtensionsTests.swift
git commit -m "$(cat <<'EOF'
feat(cobs): add Bytes extensions

cobsEncoded(framing:) and init(cobsDecoding:framing:) for ergonomic
call sites. Thin wrappers over the namespace API.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Full-suite verification + coverage check

**Files:** none modified by default. Add coverage-fill tests only if gates fail.

- [ ] **Step 1: Run the entire test suite**

Run: `swift test 2>&1 | tail -20`
Expected: all tests across all modules pass, no warnings.

- [ ] **Step 2: Generate coverage for Sources/COBS/**

Run:
```bash
swift test --enable-code-coverage 2>&1 | tail -5
PROF=$(swift test --enable-code-coverage --show-codecov-path 2>/dev/null || \
       find .build -name '*.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build' \
  $(find Sources/COBS -name '*.swift') 2>/dev/null | tail -20
```

Expected: each file in `Sources/COBS/` shows ≥ 90% line coverage.

If the report invocation above doesn't work on your platform, substitute the equivalent that other Layer 1 modules use (see prior task patterns).

- [ ] **Step 3: If coverage < 90% on any file, add targeted tests**

For each undercovered file, identify the uncovered lines from the report, write tests that exercise those paths, and commit them. Re-run Step 2. Repeat until all files pass.

If coverage already passes, skip to Step 4 with no changes.

- [ ] **Step 4: Final full-suite run**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass.

- [ ] **Step 5: Commit coverage tests if added**

```bash
# Only if Step 3 added tests
git add Tests/COBSTests
git commit -m "$(cat <<'EOF'
test(cobs): fill coverage gaps

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Update Layer 1 documentation

**Files:**
- Modify: `layers/layer-01-primitives.md`
- Modify: `README.md` (if it tracks shipped modules)

- [ ] **Step 1: Inspect current layer doc status banner**

Run: `grep -n -B1 -A3 'Shipped\|Pending\|COBS' layers/layer-01-primitives.md`

- [ ] **Step 2: Update layer doc**

Update the shipped/pending sections of `layers/layer-01-primitives.md` to:
- Move COBS from "pending" to "shipped" (the 8th module).
- Add links to the COBS spec (`docs/superpowers/specs/2026-05-17-cobs-design.md`) and plan (`docs/superpowers/plans/2026-05-17-cobs-module.md`).
- Preserve existing formatting and section structure — match how prior modules (e.g., BitSet) are listed.

- [ ] **Step 3: Update root README if it tracks modules**

Run: `grep -n -B1 -A2 'BitSet\|shipped' README.md`

If the README has a per-module index or a "shipped modules" list, add a COBS entry in the same style as BitSet. If not, skip this step.

- [ ] **Step 4: Verify links**

Run: `ls docs/superpowers/specs/2026-05-17-cobs-design.md docs/superpowers/plans/2026-05-17-cobs-module.md`
Expected: both files exist.

- [ ] **Step 5: Commit**

```bash
git add layers/layer-01-primitives.md README.md
git commit -m "$(cat <<'EOF'
docs(layer-1): mark COBS module shipped

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** Every API surface item (`encode`, `encoded`, `decode`, `decoded`, `Framing`, `COBSError`, `maxEncodedSize`, `maxDecodedSize`, Bytes extensions) has at least one task. Every test category in the spec (`COBSEncodeTests`, `COBSDecodeTests`, `COBSFramingTests`, `COBSRoundTripTests`, `COBSErrorTests`, `COBSExtensionsTests`) is covered.
- **No placeholders:** Every step contains either runnable code or an explicit command with expected output.
- **Type consistency:** All references to `Framing`, `COBSError`, `COBS.encode/encoded/decode/decoded`, and helper signatures match the spec exactly.
- **API uncertainty flagged:** Task 4 Step 1 explicitly verifies the `BytesMut` append API before encode is implemented, since spelling differences (`append(_:)` vs `putUInt8(_:)`) would propagate through later tasks.
- **TDD discipline:** Every code-producing task writes a failing test → runs it → implements → re-runs → commits.

# TaggedPointer Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `TaggedPointer<Pointee>` Layer 1 primitive per the spec at `docs/superpowers/specs/2026-05-19-tagged-pointer-design.md`.

**Architecture:** Two source files under `Sources/TaggedPointer/`. Single-`UInt` storage struct generic over `Pointee`, with tag-bit count derived from `MemoryLayout<Pointee>.alignment`. Standalone (no `Bytes` dependency). All operations are constant-time bit twiddles.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing (`import Testing`, `@Test`, `#expect`, `@Suite`).

---

## File Structure

**Sources** (`Sources/TaggedPointer/`):
- `TaggedPointer.swift` — struct definition, single-UInt storage, init, accessors, protocol conformances
- `TaggedPointerArithmetic.swift` — `tagBits`, `tagMask`, `maxTag` static helpers; `withTag`, `withPointer` derivations

**Tests** (`Tests/TaggedPointerTests/`):
- `TaggedPointerTests.swift` — basic init/accessor round-trip
- `TaggedPointerAlignmentTests.swift` — `tagBits` for various Pointee types
- `TaggedPointerBoundaryTests.swift` — null pointer, maxTag, allocation round-trip
- `TaggedPointerDerivationTests.swift` — `withTag`, `withPointer`
- `TaggedPointerConformanceTests.swift` — Equatable, Hashable, Sendable

---

## Task 1: Package scaffolding

**Files:**
- Modify: `Package.swift`
- Create: `Sources/TaggedPointer/TaggedPointer.swift` (stub)
- Create: `Sources/TaggedPointer/TaggedPointerArithmetic.swift` (stub)
- Create: `Tests/TaggedPointerTests/TaggedPointerScaffoldTests.swift` (stub)

- [ ] **Step 1: Modify Package.swift**

Add to `products:` after the UTF8Validator line:
```swift
.library(name: "TaggedPointer", targets: ["TaggedPointer"]),
```

Add to `targets:` after the UTF8Validator test target:
```swift
.target(name: "TaggedPointer", path: "Sources/TaggedPointer"),
.testTarget(name: "TaggedPointerTests", dependencies: ["TaggedPointer"], path: "Tests/TaggedPointerTests"),
```

**Note:** `TaggedPointer` does NOT depend on `Bytes` — it's standalone (per the design spec).

- [ ] **Step 2: Create stub source files**

`Sources/TaggedPointer/TaggedPointer.swift`:
```swift
/// A pointer with a small tag packed into its unused low alignment bits.
public struct TaggedPointer<Pointee> {
}
```

`Sources/TaggedPointer/TaggedPointerArithmetic.swift`:
```swift
// Static helpers and derivations.
```

- [ ] **Step 3: Create stub test**

`Tests/TaggedPointerTests/TaggedPointerScaffoldTests.swift`:
```swift
import Testing
import TaggedPointer

@Test
func scaffoldCompiles() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Verify**

Run: `swift build`
Expected: builds cleanly, zero warnings.

Run: `swift test --filter TaggedPointerTests`
Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/TaggedPointer Tests/TaggedPointerTests
git commit -m "$(cat <<'EOF'
feat(tagged-pointer): scaffold TaggedPointer module

Add library product, source target (no Bytes dep), and test target.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Core struct — storage, static helpers, init, accessors

**Files:**
- Modify: `Sources/TaggedPointer/TaggedPointer.swift`
- Modify: `Sources/TaggedPointer/TaggedPointerArithmetic.swift`
- Create: `Tests/TaggedPointerTests/TaggedPointerTests.swift`
- Delete: `Tests/TaggedPointerTests/TaggedPointerScaffoldTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/TaggedPointerTests/TaggedPointerTests.swift`:
```swift
import Testing
import TaggedPointer

@Suite
struct TaggedPointerTests {

    @Test
    func nullPointerWithDefaultTagRoundTrips() {
        let tp = TaggedPointer<UInt64>(pointer: nil)
        #expect(tp.pointer == nil)
        #expect(tp.tag == 0)
    }

    @Test
    func nullPointerWithNonZeroTagRoundTrips() {
        // UInt64 alignment 8 -> 3 tag bits, maxTag 7.
        let tp = TaggedPointer<UInt64>(pointer: nil, tag: 5)
        #expect(tp.pointer == nil)
        #expect(tp.tag == 5)
    }

    @Test
    func heapPointerWithTagRoundTrips() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }
        p.pointee = 0xDEAD_BEEF_CAFE_F00D

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 3)
        #expect(tp.pointer == p)
        #expect(tp.tag == 3)
        #expect(tp.pointer?.pointee == 0xDEAD_BEEF_CAFE_F00D)
    }

    @Test
    func heapPointerWithDefaultTagRoundTrips() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }
        let tp = TaggedPointer<UInt64>(pointer: p)
        #expect(tp.pointer == p)
        #expect(tp.tag == 0)
    }
}
```

- [ ] **Step 2: Delete scaffold + run to verify failure**

```bash
rm Tests/TaggedPointerTests/TaggedPointerScaffoldTests.swift
swift test --filter TaggedPointerTests 2>&1 | tail -20
```
Expected: compile error — `TaggedPointer.init`, `pointer`, `tag` don't exist.

- [ ] **Step 3: Implement core struct**

Replace contents of `Sources/TaggedPointer/TaggedPointer.swift`:
```swift
/// A pointer with a small tag packed into its unused low alignment bits.
///
/// `UnsafeMutablePointer<Pointee>` is guaranteed to be aligned to
/// `MemoryLayout<Pointee>.alignment`, so the low `log2(alignment)` bits
/// are always zero in a well-formed pointer and can carry a small tag
/// at no storage cost.
///
/// For `Pointee` types with alignment 8 (e.g., `Int`, `Double`), 3 tag
/// bits are available — values 0..7. For alignment-1 types (`UInt8`),
/// 0 tag bits are available; only `tag: 0` is valid.
public struct TaggedPointer<Pointee>: Equatable, Hashable, @unchecked Sendable {

    @usableFromInline
    internal let raw: UInt

    /// Build from a pointer + tag.
    /// Traps if `tag > maxTag` or if `pointer`'s low `tagBits` are nonzero.
    @inlinable
    public init(pointer: UnsafeMutablePointer<Pointee>?, tag: UInt = 0) {
        precondition(tag <= Self.maxTag,
                     "tag exceeds maxTag for this Pointee alignment")
        let pointerBits: UInt
        if let p = pointer {
            pointerBits = UInt(bitPattern: p)
            precondition(pointerBits & Self.tagMask == 0,
                         "pointer is not aligned to MemoryLayout<Pointee>.alignment")
        } else {
            pointerBits = 0
        }
        self.raw = pointerBits | tag
    }

    /// Internal raw-storage init used by `withTag` / `withPointer`.
    @usableFromInline
    internal init(rawStorage: UInt) {
        self.raw = rawStorage
    }

    /// The (untagged) pointer. `nil` if the tagged pointer was
    /// constructed from a nil pointer.
    @inlinable
    public var pointer: UnsafeMutablePointer<Pointee>? {
        let ptrBits = raw & ~Self.tagMask
        if ptrBits == 0 { return nil }
        return UnsafeMutablePointer<Pointee>(bitPattern: ptrBits)
    }

    /// The tag value (`0...maxTag`).
    @inlinable
    public var tag: UInt {
        raw & Self.tagMask
    }
}
```

- [ ] **Step 4: Implement static helpers**

Replace contents of `Sources/TaggedPointer/TaggedPointerArithmetic.swift`:
```swift
extension TaggedPointer {

    /// Number of tag bits available, derived from `Pointee`'s alignment.
    @inlinable
    public static var tagBits: Int {
        MemoryLayout<Pointee>.alignment.trailingZeroBitCount
    }

    /// Mask of bits used for the tag (`(1 << tagBits) - 1`).
    @inlinable
    public static var tagMask: UInt {
        (1 << tagBits) - 1
    }

    /// Maximum representable tag value (same as `tagMask`).
    @inlinable
    public static var maxTag: UInt { tagMask }
}
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter TaggedPointerTests 2>&1 | tail -10
```
Expected: 4 `TaggedPointerTests` pass.

```bash
swift test 2>&1 | tail -5
```
Expected: full suite green.

- [ ] **Step 6: Commit**

```bash
git add Sources/TaggedPointer Tests/TaggedPointerTests
git commit -m "$(cat <<'EOF'
feat(tagged-pointer): add core type with init and accessors

Single-UInt storage struct generic over Pointee. Tag-bit count derived
from MemoryLayout<Pointee>.alignment via trailingZeroBitCount.
Equatable, Hashable, @unchecked Sendable synthesized.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Derivations (withTag, withPointer)

**Files:**
- Modify: `Sources/TaggedPointer/TaggedPointerArithmetic.swift`
- Create: `Tests/TaggedPointerTests/TaggedPointerDerivationTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/TaggedPointerTests/TaggedPointerDerivationTests.swift`:
```swift
import Testing
import TaggedPointer

@Suite
struct TaggedPointerDerivationTests {

    @Test
    func withTagSetsNewTagPointerUnchanged() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 2)
        let derived = tp.withTag(5)
        #expect(derived.pointer == p)
        #expect(derived.tag == 5)
    }

    @Test
    func withTagZeroClearsTag() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 7)
        let cleared = tp.withTag(0)
        #expect(cleared.pointer == p)
        #expect(cleared.tag == 0)
    }

    @Test
    func withPointerSetsNewPointerTagUnchanged() {
        let p1 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p1.deallocate() }
        let p2 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p2.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p1, tag: 4)
        let derived = tp.withPointer(p2)
        #expect(derived.pointer == p2)
        #expect(derived.tag == 4)
    }

    @Test
    func withPointerNilClearsPointerTagUnchanged() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 3)
        let derived = tp.withPointer(nil)
        #expect(derived.pointer == nil)
        #expect(derived.tag == 3)
    }

    @Test
    func chainedDerivation() {
        let p1 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p1.deallocate() }
        let p2 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p2.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p1, tag: 1)
        let result = tp.withTag(2).withPointer(p2).withTag(5)
        #expect(result.pointer == p2)
        #expect(result.tag == 5)
    }

    @Test
    func derivationDoesNotMutateOriginal() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 3)
        _ = tp.withTag(7)
        // Original unchanged.
        #expect(tp.pointer == p)
        #expect(tp.tag == 3)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter TaggedPointerDerivationTests 2>&1 | tail -10
```
Expected: compile error — `withTag` / `withPointer` don't exist.

- [ ] **Step 3: Implement derivations**

Append to `Sources/TaggedPointer/TaggedPointerArithmetic.swift` (inside the same `extension TaggedPointer { ... }` block, after the static helpers):

```swift
    /// Derive a new tagged pointer with a different tag, same pointer.
    /// Traps if `newTag > maxTag`.
    @inlinable
    public func withTag(_ newTag: UInt) -> TaggedPointer<Pointee> {
        precondition(newTag <= Self.maxTag,
                     "tag exceeds maxTag for this Pointee alignment")
        let pointerBits = raw & ~Self.tagMask
        return TaggedPointer(rawStorage: pointerBits | newTag)
    }

    /// Derive a new tagged pointer with a different pointer, same tag.
    /// Traps if the new pointer's low `tagBits` are nonzero.
    @inlinable
    public func withPointer(_ newPointer: UnsafeMutablePointer<Pointee>?) -> TaggedPointer<Pointee> {
        TaggedPointer(pointer: newPointer, tag: tag)
    }
```

- [ ] **Step 4: Run**

```bash
swift test --filter TaggedPointerDerivationTests 2>&1 | tail -10
```
Expected: 6 derivation tests pass.

```bash
swift test 2>&1 | tail -5
```
Expected: full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/TaggedPointer Tests/TaggedPointerTests
git commit -m "$(cat <<'EOF'
feat(tagged-pointer): add withTag and withPointer derivations

Pure derivations returning new TaggedPointer values. withTag operates
on the storage directly; withPointer delegates to init for alignment
validation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Alignment and boundary tests

**Files:**
- Create: `Tests/TaggedPointerTests/TaggedPointerAlignmentTests.swift`
- Create: `Tests/TaggedPointerTests/TaggedPointerBoundaryTests.swift`

- [ ] **Step 1: Write alignment tests**

Create `Tests/TaggedPointerTests/TaggedPointerAlignmentTests.swift`:
```swift
import Testing
import TaggedPointer

@Suite
struct TaggedPointerAlignmentTests {

    @Test
    func uint8HasZeroTagBits() {
        #expect(TaggedPointer<UInt8>.tagBits == 0)
        #expect(TaggedPointer<UInt8>.tagMask == 0)
        #expect(TaggedPointer<UInt8>.maxTag == 0)
    }

    @Test
    func uint16HasOneTagBit() {
        #expect(TaggedPointer<UInt16>.tagBits == 1)
        #expect(TaggedPointer<UInt16>.tagMask == 1)
        #expect(TaggedPointer<UInt16>.maxTag == 1)
    }

    @Test
    func uint32HasTwoTagBits() {
        #expect(TaggedPointer<UInt32>.tagBits == 2)
        #expect(TaggedPointer<UInt32>.tagMask == 3)
        #expect(TaggedPointer<UInt32>.maxTag == 3)
    }

    @Test
    func uint64HasThreeTagBits() {
        #expect(TaggedPointer<UInt64>.tagBits == 3)
        #expect(TaggedPointer<UInt64>.tagMask == 7)
        #expect(TaggedPointer<UInt64>.maxTag == 7)
    }

    @Test
    func intTagBitsMatchAlignment() {
        // Platform-aware: 3 on 64-bit, 2 on 32-bit.
        let expected = MemoryLayout<Int>.alignment.trailingZeroBitCount
        #expect(TaggedPointer<Int>.tagBits == expected)
    }

    @Test
    func doubleHasThreeTagBits() {
        #expect(TaggedPointer<Double>.tagBits == 3)
    }
}
```

- [ ] **Step 2: Write boundary tests**

Create `Tests/TaggedPointerTests/TaggedPointerBoundaryTests.swift`:
```swift
import Testing
import TaggedPointer

@Suite
struct TaggedPointerBoundaryTests {

    @Test
    func tagAtMaxRoundTrips() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: TaggedPointer<UInt64>.maxTag)
        #expect(tp.tag == 7)
        #expect(tp.pointer == p)
    }

    @Test
    func tagZeroRoundTripsWithNonNullPointer() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 0)
        #expect(tp.tag == 0)
        #expect(tp.pointer == p)
    }

    @Test
    func allTagValuesRoundTripForUInt64() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        for t: UInt in 0 ... 7 {
            let tp = TaggedPointer<UInt64>(pointer: p, tag: t)
            #expect(tp.tag == t)
            #expect(tp.pointer == p)
        }
    }

    @Test
    func uint8PointerWithZeroTagRoundTrips() {
        // UInt8 alignment 1 -> 0 tag bits; only tag 0 is valid.
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt8>(pointer: p, tag: 0)
        #expect(tp.pointer == p)
        #expect(tp.tag == 0)
    }

    @Test
    func uint16PointerWithBothTagValuesRoundTrips() {
        let p = UnsafeMutablePointer<UInt16>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp0 = TaggedPointer<UInt16>(pointer: p, tag: 0)
        #expect(tp0.tag == 0)
        #expect(tp0.pointer == p)

        let tp1 = TaggedPointer<UInt16>(pointer: p, tag: 1)
        #expect(tp1.tag == 1)
        #expect(tp1.pointer == p)
    }
}
```

- [ ] **Step 3: Run**

```bash
swift test --filter TaggedPointerAlignmentTests 2>&1 | tail -5
swift test --filter TaggedPointerBoundaryTests 2>&1 | tail -5
```
Expected: 6 alignment + 5 boundary = 11 tests pass.

- [ ] **Step 4: Commit**

```bash
git add Tests/TaggedPointerTests
git commit -m "$(cat <<'EOF'
test(tagged-pointer): alignment and boundary coverage

Tag-bit derivation for UInt8/16/32/64/Int/Double; max-tag round-trip;
all tag values for UInt64; UInt8 (0 tag bits) edge case.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Protocol conformance tests

**Files:**
- Create: `Tests/TaggedPointerTests/TaggedPointerConformanceTests.swift`

- [ ] **Step 1: Write tests**

Create `Tests/TaggedPointerTests/TaggedPointerConformanceTests.swift`:
```swift
import Testing
import TaggedPointer

@Suite
struct TaggedPointerConformanceTests {

    @Test
    func equatableSamePointerSameTag() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let a = TaggedPointer<UInt64>(pointer: p, tag: 3)
        let b = TaggedPointer<UInt64>(pointer: p, tag: 3)
        #expect(a == b)
    }

    @Test
    func equatableSamePointerDifferentTag() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let a = TaggedPointer<UInt64>(pointer: p, tag: 3)
        let b = TaggedPointer<UInt64>(pointer: p, tag: 4)
        #expect(a != b)
    }

    @Test
    func equatableDifferentPointerSameTag() {
        let p1 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p1.deallocate() }
        let p2 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p2.deallocate() }

        let a = TaggedPointer<UInt64>(pointer: p1, tag: 3)
        let b = TaggedPointer<UInt64>(pointer: p2, tag: 3)
        #expect(a != b)
    }

    @Test
    func equatableBothNullDifferentTag() {
        let a = TaggedPointer<UInt64>(pointer: nil, tag: 0)
        let b = TaggedPointer<UInt64>(pointer: nil, tag: 1)
        #expect(a != b)
    }

    @Test
    func hashableEqualValuesHashEqual() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let a = TaggedPointer<UInt64>(pointer: p, tag: 3)
        let b = TaggedPointer<UInt64>(pointer: p, tag: 3)
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }

    @Test
    func hashableUsableInSet() {
        let p1 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p1.deallocate() }
        let p2 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p2.deallocate() }

        var s = Set<TaggedPointer<UInt64>>()
        s.insert(TaggedPointer(pointer: p1, tag: 0))
        s.insert(TaggedPointer(pointer: p1, tag: 0))   // duplicate
        s.insert(TaggedPointer(pointer: p1, tag: 1))
        s.insert(TaggedPointer(pointer: p2, tag: 0))
        s.insert(TaggedPointer(pointer: nil, tag: 0))
        #expect(s.count == 4)
    }

    @Test
    func sendable() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 3)
        Task.detached { @Sendable in
            let _ = tp
        }
    }
}
```

- [ ] **Step 2: Run**

```bash
swift test --filter TaggedPointerConformanceTests 2>&1 | tail -10
```
Expected: 7 conformance tests pass.

```bash
swift test 2>&1 | tail -5
```
Expected: full suite green.

- [ ] **Step 3: Commit**

```bash
git add Tests/TaggedPointerTests
git commit -m "$(cat <<'EOF'
test(tagged-pointer): protocol conformance coverage

Equatable (same/different pointer/tag combinations), Hashable
(equal-values-equal-hash, Set semantics), Sendable (cross-actor).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Coverage verification + layer doc update

**Files:**
- Possibly: `Tests/TaggedPointerTests/*` (coverage fill-ins, if needed)
- Modify: `layers/layer-01-primitives.md`

- [ ] **Step 1: Run full suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass, zero warnings. New total: previous full-suite count + (4 + 6 + 6 + 5 + 7) = +28.

- [ ] **Step 2: Generate coverage**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build' \
  Sources/TaggedPointer/TaggedPointer.swift \
  Sources/TaggedPointer/TaggedPointerArithmetic.swift
```

Expected: both files ≥ 90% line coverage.

If `TaggedPointer.swift` falls below the gate due to precondition-message autoclosures (a known artifact from prior modules), drop the message strings — same fix used in COBS. The trap site source location is sufficient.

- [ ] **Step 3: Commit fix if needed**

```bash
# Only if precondition messages were dropped or fill-in tests added
git add Sources/TaggedPointer Tests/TaggedPointerTests
git commit -m "$(cat <<'EOF'
refactor(tagged-pointer): drop precondition messages

Eliminates uncovered autoclosure regions without losing trap-site
source location.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Update Layer 1 doc**

Edit `layers/layer-01-primitives.md`. The "shipping modules" list currently ends with `Sources/UTF8Validator/`. Add a TaggedPointer entry.

Before:
```
> - `Sources/UTF8Validator/` — strict UTF-8 byte-sequence validator (RFC 3629) with first-invalid-byte offset reporting; scalar Hoehrmann DFA, SIMD fast path deferred ([design](../docs/superpowers/specs/2026-05-18-utf8-validator-design.md), [plan](../docs/superpowers/plans/2026-05-18-utf8-validator-module.md))
>
> Remaining categories (URL/IDNA) pending their own designs.
```

After:
```
> - `Sources/UTF8Validator/` — strict UTF-8 byte-sequence validator (RFC 3629) with first-invalid-byte offset reporting; scalar Hoehrmann DFA, SIMD fast path deferred ([design](../docs/superpowers/specs/2026-05-18-utf8-validator-design.md), [plan](../docs/superpowers/plans/2026-05-18-utf8-validator-module.md))
> - `Sources/TaggedPointer/` — generic value type packing a small tag into the unused low alignment bits of `UnsafeMutablePointer<Pointee>`; atomic variant deferred to Layer 10 ([design](../docs/superpowers/specs/2026-05-19-tagged-pointer-design.md), [plan](../docs/superpowers/plans/2026-05-19-tagged-pointer-module.md))
>
> Remaining categories (URL/IDNA) pending their own designs.
```

- [ ] **Step 5: Commit**

```bash
git add layers/layer-01-primitives.md
git commit -m "$(cat <<'EOF'
docs(layer-1): mark TaggedPointer module shipped

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** Every API surface item (`init`, `pointer`, `tag`, `tagBits`, `tagMask`, `maxTag`, `withTag`, `withPointer`) has at least one task. Every test category in the spec (basic round-trip, alignment, boundary, derivation, conformance) is covered.
- **No placeholders:** Every step contains runnable code or an exact command + expected output.
- **Type consistency:** All references use `TaggedPointer<Pointee>` generic syntax; method signatures match the spec verbatim.
- **No `Bytes` dependency:** Confirmed in Package.swift entry — the target has no `dependencies:` list.
- **Precondition coverage artifact preemptively addressed:** Task 6 Step 2 instructs dropping precondition messages if coverage falls short, following the established pattern from the COBS module fix.
- **Allocation discipline in tests:** Every test that allocates an `UnsafeMutablePointer` uses `defer { p.deallocate() }`. No leaks.

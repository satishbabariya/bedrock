# TaggedPointer Module Design

**Status:** Approved
**Layer:** 1 — Primitives
**Depends on:** stdlib only (no `Bytes`)
**Date:** 2026-05-19

## Purpose

Provide a Layer 1 primitive for packing a small tag into the unused low alignment bits of a typed pointer. `UnsafeMutablePointer<Pointee>` is guaranteed to be aligned to `MemoryLayout<Pointee>.alignment`, so the low `log2(alignment)` bits are always zero in a well-formed pointer and can carry a tag at no storage cost.

Used downstream by Layer 9 (collections — e.g., hash-table header tags) and Layer 11 (runtime — lock-free state encoding). v1 is the synchronous, single-threaded primitive; an atomic variant is a separate Layer 10 primitive.

## Scope

### In scope (v1)

- A generic `TaggedPointer<Pointee>` value type with single-`UInt` storage.
- Tag-bit count derived statically from `MemoryLayout<Pointee>.alignment`.
- Static helpers: `tagBits`, `tagMask`, `maxTag`.
- Construction: `init(pointer:, tag:)` with default `tag: 0`.
- Accessors: `pointer`, `tag`.
- Derivations: `withTag(_:)`, `withPointer(_:)`.
- Protocol conformances: `Equatable`, `Hashable`, `@unchecked Sendable`.
- Nullable pointer (`UnsafeMutablePointer<Pointee>?`) — null + tag is valid storage.

### Out of scope (separate primitives when needed)

- **`TaggedReference<T: AnyObject>`** — class-reference tagging via `Unmanaged`. Separate primitive; involves ARC-lifetime concerns absent here.
- **`AtomicTaggedPointer`** — CAS, compare-exchange, ABA counters. Layer 10 (concurrency).
- **High-bit tagging** (using bits 48+ on 64-bit hosts). Platform-dependent and niche.
- **NaN-boxing** — `Double`-based packed values for dynamic language runtimes. Out of scope.
- **Pointer compression** (JVM-style 32-bit refs on 64-bit hosts). Out of scope.
- **Generic over tag bit count** (`TaggedPointer<Pointee, N: NumBits>`). Stay simple: tag bits derive from alignment.
- **`Comparable`** — ordering of tagged pointers is rarely meaningful; conform downstream if needed.
- **`CustomStringConvertible` / `CustomDebugStringConvertible`** — easy to add later.
- **Bytes interop** — pointers aren't bytes; the internal `UInt` is platform-dependent and has no useful serialization story.

## Module Layout

```
Sources/TaggedPointer/
├── TaggedPointer.swift              # struct, init, accessors, conformances
└── TaggedPointerArithmetic.swift    # withTag, withPointer, static helpers
```

```
Tests/TaggedPointerTests/
├── TaggedPointerTests.swift
├── TaggedPointerAlignmentTests.swift
├── TaggedPointerBoundaryTests.swift
├── TaggedPointerDerivationTests.swift
└── TaggedPointerConformanceTests.swift
```

## Public API

```swift
/// A pointer with a small tag packed into its unused low alignment bits.
///
/// `UnsafeMutablePointer<Pointee>` is guaranteed to be aligned to
/// `MemoryLayout<Pointee>.alignment`, so the low `log2(alignment)` bits
/// are always zero in a well-formed pointer and can carry a small tag
/// at no storage cost.
///
/// For `Pointee` types with alignment 8 (e.g., `Int`, `Double`, most
/// classes' instance pointers), 3 tag bits are available — values 0..7.
/// For alignment-1 types (`UInt8`), 0 tag bits are available; only
/// `tag: 0` is valid.
public struct TaggedPointer<Pointee>: Equatable, Hashable, @unchecked Sendable {

    /// Number of tag bits available, derived from `Pointee`'s alignment.
    public static var tagBits: Int { get }

    /// Mask of bits used for the tag (`(1 << tagBits) - 1`).
    public static var tagMask: UInt { get }

    /// Maximum representable tag value (same as `tagMask`).
    public static var maxTag: UInt { get }

    /// The (untagged) pointer. `nil` if the tagged pointer was
    /// constructed from a nil pointer with `tag: 0`.
    public var pointer: UnsafeMutablePointer<Pointee>? { get }

    /// The tag value (`0...maxTag`).
    public var tag: UInt { get }

    /// Build from a pointer + tag.
    /// Traps if `tag > maxTag` or if the pointer's low `tagBits` are nonzero.
    public init(pointer: UnsafeMutablePointer<Pointee>?, tag: UInt = 0)

    /// Derive a new tagged pointer with a different tag, same pointer.
    /// Traps if `newTag > maxTag`.
    public func withTag(_ newTag: UInt) -> TaggedPointer<Pointee>

    /// Derive a new tagged pointer with a different pointer, same tag.
    /// Traps if the new pointer's low `tagBits` are nonzero.
    public func withPointer(_ newPointer: UnsafeMutablePointer<Pointee>?) -> TaggedPointer<Pointee>
}
```

### Bit layout (illustrative; alignment 8, 64-bit host)

```
 63                                       3 2 1 0
┌─────────────────────────────────────────┬─────┐
│         pointer bits (must be aligned)  │ tag │
└─────────────────────────────────────────┴─────┘
                                            └── 3 bits, 0..7
```

Storage is a single `UInt` combining pointer bits and tag bits via bitwise OR. No allocation, no indirection.

## Invariants and Precondition Semantics

1. **Tag overflow traps.** `init(pointer:, tag:)` and `withTag(_:)` trap if `tag > maxTag`. Silently masking would corrupt round-trip semantics (callers expect what they put in to come back out).

2. **Misaligned input traps.** `init(pointer:, tag:)` and `withPointer(_:)` trap if the input pointer's low `tagBits` are nonzero. Such a pointer is malformed (violates `UnsafeMutablePointer<Pointee>`'s alignment contract); silently masking would hide caller bugs and surprise readers of `pointer`.

3. **Round-trip identity.** For any valid aligned `p` and `t ∈ 0...maxTag`:
   - `TaggedPointer(pointer: p, tag: t).pointer == p`
   - `TaggedPointer(pointer: p, tag: t).tag == t`

4. **`tag` is always in range.** The accessor masks with `tagMask`; the type-level guarantee is `tag <= maxTag`.

5. **Pure derivations.** `withTag` and `withPointer` return new values; they do not mutate.

6. **Null + tag is valid.** `TaggedPointer(pointer: nil, tag: 5)` is well-formed (for `Pointee` with `maxTag >= 5`). `pointer` returns `nil`, `tag` returns `5`.

### Equality semantics

Two `TaggedPointer<Pointee>` values are equal iff both pointer and tag are equal. Since storage is a single `UInt`, equality is one machine-word comparison.

## Testing Strategy

Each test file targets ≥ 90% line coverage on its corresponding source file.

### `TaggedPointerTests.swift` — basic functionality
- Round-trip a heap-allocated `UInt64` pointer with each tag in `0...7`.
- Default `tag: 0` round-trips.
- `init(pointer: nil, tag: 0)` → `pointer == nil`, `tag == 0`.
- `init(pointer: nil, tag: 3)` (with alignment ≥ 4 Pointee) → `pointer == nil`, `tag == 3`.

### `TaggedPointerAlignmentTests.swift` — derived tag-bit counts
- `TaggedPointer<UInt8>.tagBits == 0`, `maxTag == 0`, `tagMask == 0`.
- `TaggedPointer<UInt16>.tagBits == 1`, `maxTag == 1`, `tagMask == 1`.
- `TaggedPointer<UInt32>.tagBits == 2`, `maxTag == 3`, `tagMask == 3`.
- `TaggedPointer<UInt64>.tagBits == 3`, `maxTag == 7`, `tagMask == 7`.
- `TaggedPointer<Int>.tagBits == MemoryLayout<Int>.alignment.trailingZeroBitCount` (3 on 64-bit, 2 on 32-bit — assertion stays platform-aware).
- Tuple of two `UInt32`s (alignment 4) → 2 tag bits.

### `TaggedPointerBoundaryTests.swift` — boundaries
- Tag at exactly `maxTag` round-trips.
- Tag 0 round-trips for non-null pointer.
- Construct from explicitly-allocated `UnsafeMutablePointer<UInt64>.allocate(capacity: 1)`, tag with 7, retrieve, deallocate.
- For `Pointee == UInt8` (0 tag bits): only `tag: 0` is constructible; document as a design property.

(Tag overflow and misaligned-pointer trapping are precondition traps — verified by design intent, not by unit test, since traps abort the process.)

### `TaggedPointerDerivationTests.swift` — derivations
- `tp.withTag(new).tag == new`; pointer unchanged.
- `tp.withTag(0)` clears the tag.
- `tp.withPointer(p2).pointer == p2`; tag unchanged.
- `tp.withPointer(nil).pointer == nil`; tag unchanged.
- Chained: `tp.withTag(2).withPointer(p2).withTag(5)` yields `(p2, 5)`.

### `TaggedPointerConformanceTests.swift` — protocol conformances
- `Equatable`: same `(p, t)` → equal; same `p` different `t` → unequal; different `p` same `t` → unequal.
- `Hashable`: equal values hash equal; `Set` membership semantics.
- `Sendable`: compile-time check via cross-actor stub.

## Non-Functional Requirements

- **Stdlib only.** No Foundation, no swift-system, no swift-atomics, no Bytes.
- **Zero allocation.** Single `UInt` storage, value semantics throughout.
- **`@unchecked Sendable`.** The internal `UInt` is trivially `Sendable`; pointer-referent safety is the caller's concern (same contract as raw `UnsafePointer`).
- **Constant-time everything.** All operations are bit twiddles on a single `UInt`.
- **Platform-aware alignment.** Tag-bit count derives from `MemoryLayout<Pointee>.alignment` at the type-level; no hard-coded "3 bits" assumption.

## Open Questions

None. All resolved during brainstorming:
- Tag bits: derived from alignment (not generic-parameterized).
- Misaligned input: trap (not mask).
- Null + tag: supported.
- Bytes interop: none (out of scope; non-portable).
- Class-reference tagging: separate primitive (deferred).
- Atomic variant: Layer 10 concern (deferred).

# Bedrock `Bytes` Module — Design Spec

**Date:** 2026-05-09
**Layer:** 1 (Primitives, Bytes, Encodings) — *core bytes subset*
**Status:** Approved, ready for implementation plan

---

## 1. Scope & Non-Goals

### In scope

- A refcounted byte storage backing two public types:
  - `Bytes` — immutable, zero-copy view; `Sendable`; `RandomAccessCollection<UInt8>`.
  - `BytesMut` — mutable builder with copy-on-write; freezes into `Bytes`.
- `BytesReader` — `~Copyable` cursor over a `Bytes`, providing advancing reads.
- Endian-aware fixed-width integer reads, peeks, and writes for `UInt8/16/32/64` and `Int8/16/32/64`.
- Zero-copy slicing on `Bytes` (`prefix`, `suffix`, `dropFirst`, `dropLast`, subscript ranges).
- Indexed non-advancing peeks on `Bytes` (`peekUInt32(at:endianness:)` etc.).
- Two parallel error surfaces: optional-returning by default, throwing variants (`tryPeek*`, `tryRead*`) for richer error context.
- Stdlib-only implementation: no Foundation, no swift-system, no swift-atomics, no swift-collections.

### Explicitly out of scope (separate designs later)

- Hex, Base64, Base32/58/85, percent encoding, form encoding, varints (LEB128, ZigZag), UUID, BitSet, SIMD UTF-8 validation, COBS, tagged pointers, URL/URI parser, IDNA. All of these consume `Bytes` and live in their own modules.
- Async I/O, file/socket integration, streaming reads — these wait on Layer 11.
- Foundation `Data` interop — only relevant if Foundation lands on the user side.
- `Codable` conformance — Layer 14 owns serialization holistically.
- Property-based testing infrastructure — Layer 25.

---

## 2. Package Layout

```
Bedrock/
├── Package.swift                 # name: Bedrock, swift-tools-version: 5.10
├── Sources/
│   └── Bytes/
│       ├── Bytes.swift           # public struct Bytes
│       ├── BytesMut.swift        # public struct BytesMut
│       ├── BytesReader.swift     # public struct BytesReader (~Copyable)
│       ├── BytesStorage.swift    # internal final class (refcounted heap buffer)
│       ├── Endianness.swift      # public enum Endianness
│       ├── BytesError.swift      # public enum BytesError: Error
│       └── Internal/
│           ├── UnsafeReads.swift # loadFixed / storeFixed helpers
│           └── Allocator.swift   # allocate/deallocate + growth policy
└── Tests/
    └── BytesTests/
        ├── BytesTests.swift
        ├── BytesMutTests.swift
        ├── BytesReaderTests.swift
        ├── EndiannessTests.swift
        └── CowTests.swift
```

- `swift-tools-version: 5.10` — keeps Swift 6 concurrency available without forcing 6.0.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`).
- One module published as a library product: `.library(name: "Bytes", targets: ["Bytes"])`.

---

## 3. Public API Surface

### 3.1 `Bytes` — immutable view

```swift
public struct Bytes: Sendable, Hashable {
    public static let empty: Bytes
    public init()
    public init<S: Sequence>(_ bytes: S) where S.Element == UInt8

    public var count: Int { get }
    public var isEmpty: Bool { get }

    public subscript(index: Int) -> UInt8 { get }
    public subscript(range: Range<Int>) -> Bytes { get }   // zero-copy

    public func prefix(_ n: Int) -> Bytes
    public func suffix(_ n: Int) -> Bytes
    public func dropFirst(_ n: Int) -> Bytes
    public func dropLast(_ n: Int) -> Bytes

    // Non-advancing peeks; nil out-of-bounds.
    public func peekUInt8 (at offset: Int) -> UInt8?
    public func peekUInt16(at offset: Int, endianness: Endianness) -> UInt16?
    public func peekUInt32(at offset: Int, endianness: Endianness) -> UInt32?
    public func peekUInt64(at offset: Int, endianness: Endianness) -> UInt64?
    public func peekInt8  (at offset: Int) -> Int8?
    public func peekInt16 (at offset: Int, endianness: Endianness) -> Int16?
    public func peekInt32 (at offset: Int, endianness: Endianness) -> Int32?
    public func peekInt64 (at offset: Int, endianness: Endianness) -> Int64?
    public func peekBytes(at offset: Int, length: Int) -> Bytes?

    // Throwing peeks; throw BytesError.outOfBounds(...).
    public func tryPeekUInt8 (at offset: Int) throws -> UInt8
    public func tryPeekUInt16(at offset: Int, endianness: Endianness) throws -> UInt16
    public func tryPeekUInt32(at offset: Int, endianness: Endianness) throws -> UInt32
    public func tryPeekUInt64(at offset: Int, endianness: Endianness) throws -> UInt64
    public func tryPeekInt8  (at offset: Int) throws -> Int8
    public func tryPeekInt16 (at offset: Int, endianness: Endianness) throws -> Int16
    public func tryPeekInt32 (at offset: Int, endianness: Endianness) throws -> Int32
    public func tryPeekInt64 (at offset: Int, endianness: Endianness) throws -> Int64
    public func tryPeekBytes(at offset: Int, length: Int) throws -> Bytes

    public func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R
}

extension Bytes: RandomAccessCollection { /* startIndex, endIndex, indices */ }
extension Bytes: ExpressibleByArrayLiteral { /* [0xDE, 0xAD] */ }
```

### 3.2 `BytesMut` — mutable builder

```swift
public struct BytesMut {
    public init()
    public init(capacity: Int)
    public init<S: Sequence>(_ bytes: S) where S.Element == UInt8

    public var count: Int { get }
    public var capacity: Int { get }
    public var isEmpty: Bool { get }

    public mutating func reserveCapacity(_ n: Int)
    public mutating func clear()                       // count = 0; storage retained when uniquely owned

    public mutating func putUInt8 (_ v: UInt8)
    public mutating func putUInt16(_ v: UInt16, endianness: Endianness)
    public mutating func putUInt32(_ v: UInt32, endianness: Endianness)
    public mutating func putUInt64(_ v: UInt64, endianness: Endianness)
    public mutating func putInt8  (_ v: Int8)
    public mutating func putInt16 (_ v: Int16,  endianness: Endianness)
    public mutating func putInt32 (_ v: Int32,  endianness: Endianness)
    public mutating func putInt64 (_ v: Int64,  endianness: Endianness)

    public mutating func putBytes<S: Sequence>(_ bytes: S) where S.Element == UInt8
    public mutating func putBytes(_ other: Bytes)

    public mutating func freeze() -> Bytes             // hands off; resets builder to empty
    public func snapshot() -> Bytes                    // non-consuming; CoW on next mutation

    public mutating func withUnsafeMutableBytes<R>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> R
    ) rethrows -> R
}
```

### 3.3 `BytesReader` — cursor

```swift
public struct BytesReader: ~Copyable {
    public init(_ bytes: Bytes)

    public var remaining: Int { get }
    public var consumed:  Int { get }
    public var isExhausted: Bool { get }

    // Optional reads: nil on short read; do NOT advance.
    public mutating func readUInt8 () -> UInt8?
    public mutating func readUInt16(endianness: Endianness) -> UInt16?
    public mutating func readUInt32(endianness: Endianness) -> UInt32?
    public mutating func readUInt64(endianness: Endianness) -> UInt64?
    public mutating func readInt8  () -> Int8?
    public mutating func readInt16 (endianness: Endianness) -> Int16?
    public mutating func readInt32 (endianness: Endianness) -> Int32?
    public mutating func readInt64 (endianness: Endianness) -> Int64?
    public mutating func readBytes(length: Int) -> Bytes?       // zero-copy

    // Throwing variants: BytesError.shortRead(needed:available:).
    public mutating func tryReadUInt8 () throws -> UInt8
    public mutating func tryReadUInt16(endianness: Endianness) throws -> UInt16
    public mutating func tryReadUInt32(endianness: Endianness) throws -> UInt32
    public mutating func tryReadUInt64(endianness: Endianness) throws -> UInt64
    public mutating func tryReadInt8  () throws -> Int8
    public mutating func tryReadInt16 (endianness: Endianness) throws -> Int16
    public mutating func tryReadInt32 (endianness: Endianness) throws -> Int32
    public mutating func tryReadInt64 (endianness: Endianness) throws -> Int64
    public mutating func tryReadBytes(length: Int) throws -> Bytes

    public mutating func skip(_ n: Int) -> Bool                 // true if skipped n
    public mutating func trySkip(_ n: Int) throws

    public func remainingBytes() -> Bytes
}
```

### 3.4 `Endianness`

```swift
public enum Endianness: Sendable {
    case big           // network byte order
    case little
    case host          // platform-native — see note below
}
```

`.host` exists for the rare cases where bytes really are produced and consumed on the same machine (shared-memory IPC, on-disk caches keyed to the host architecture). Public-protocol code should pick `.big` or `.little` explicitly. Doc comment on the case will say so.

### 3.5 `BytesError`

```swift
public enum BytesError: Error, Equatable, Sendable {
    case outOfBounds(offset: Int, length: Int, bufferCount: Int)
    case shortRead  (needed: Int, available: Int)
    case invalidLength(Int)
}
```

---

## 4. Storage, Refcounting, Copy-on-Write

### 4.1 `BytesStorage`

```swift
internal final class BytesStorage {
    var pointer: UnsafeMutableRawPointer
    var capacity: Int

    init(capacity: Int)         // allocate(byteCount:alignment:)
    deinit                      // deallocate()

    func grow(to newCapacity: Int)   // allocate-new + copy + deallocate-old
}
```

- Class reference handles atomic refcounting via Swift ARC; no `swift-atomics` dependency.
- Allocation uses `UnsafeMutableRawPointer.allocate(byteCount:alignment:)` from stdlib.
- Alignment is `MemoryLayout<UInt64>.alignment` (8) so 64-bit unaligned-load tricks remain safe.
- `BytesStorage.empty` is a static singleton with `capacity: 0` shared by all empty `Bytes`/`BytesMut` instances.

### 4.2 `Bytes` layout

```swift
public struct Bytes {
    @usableFromInline let storage: BytesStorage
    @usableFromInline let offset:  Int
    @usableFromInline let length:  Int
}
```

- Slicing keeps the same `storage`; narrows `offset`/`length`. Zero copy.
- `Sendable`: from a `Bytes`'s point of view the bytes are immutable. The internal class is `@unchecked Sendable`; legal because mutation happens only via `BytesMut`, which triggers CoW into a fresh storage if any `Bytes` is outstanding.

### 4.3 `BytesMut` layout

```swift
public struct BytesMut {
    @usableFromInline var storage: BytesStorage
    @usableFromInline var count:   Int    // bytes used
}
```

- No `offset`: a builder always owns the prefix `[0..<count]`.
- Before any in-place mutation:
  - `isKnownUniquelyReferenced(&storage)` true → write in place; `realloc` for growth.
  - false → allocate a new storage, copy the live prefix, swap. Future writes go into the new storage.
- `freeze() -> Bytes` returns `Bytes(storage: self.storage, offset: 0, length: self.count)`, then resets `self` to a builder over the empty singleton.
- `snapshot() -> Bytes` returns `Bytes(storage: self.storage, offset: 0, length: self.count)` without resetting. The next mutation triggers CoW if the snapshot still exists, leaving the snapshot's bytes intact.
- `clear()` sets `count = 0` and retains the storage (no deallocation) when uniquely owned; if shared, drops to the empty singleton so future writes pick up a fresh allocation lazily.

### 4.4 Growth policy

- On reallocation, new capacity = `max(needed, capacity * 2)`, capped at `Int.max / 2`.
- Default initial capacity is 0 (empty singleton).
- The first write to a builder backed by the empty singleton allocates 64 bytes, then doubles from there.

---

## 5. Endianness, Unaligned Loads, Byte Swaps

```swift
@inlinable
internal func loadFixed<T: FixedWidthInteger>(
    _ type: T.Type,
    from base: UnsafeRawPointer,
    offset: Int,
    endianness: Endianness
) -> T {
    let raw = base.loadUnaligned(fromByteOffset: offset, as: T.self)
    switch endianness {
    case .big:    return T(bigEndian: raw)
    case .little: return T(littleEndian: raw)
    case .host:   return raw
    }
}

@inlinable
internal func storeFixed<T: FixedWidthInteger>(
    _ value: T,
    to base: UnsafeMutableRawPointer,
    offset: Int,
    endianness: Endianness
) {
    let raw: T
    switch endianness {
    case .big:    raw = value.bigEndian
    case .little: raw = value.littleEndian
    case .host:   raw = value
    }
    base.storeBytes(of: raw, toByteOffset: offset, as: T.self)
}
```

- Reads use `loadUnaligned(fromByteOffset:as:)` — required because network buffers are typically not aligned to `T`.
- Writes use `storeBytes(of:toByteOffset:as:)` which does not require alignment.
- `bigEndian`/`littleEndian` on `FixedWidthInteger` lower to `bswap` / `rev` instructions; no manual intrinsics.
- `UInt8`/`Int8` overloads bypass these helpers entirely — endianness is irrelevant for single bytes.
- `peek*`/`read*` validate bounds before invoking `loadFixed`, so the unsafe load always sees a verified offset.

---

## 6. Error Model

Two parallel surfaces, both available for every operation that can fail:

1. **Optional-returning** — `peekUInt32(at:endianness:) -> UInt32?`, `readUInt32(endianness:) -> UInt32?`. Returns `nil` on out-of-bounds / short read; reader does not advance. Primary surface.
2. **Throwing** — `tryPeekUInt32(at:endianness:)`, `tryReadUInt32(endianness:)`. Throws `BytesError` carrying `needed`/`available`/`offset` for callers that propagate structured errors.

`BytesError`:

| Case | Used by |
|---|---|
| `outOfBounds(offset:length:bufferCount:)` | `tryPeek*`, `tryPeekBytes` |
| `shortRead(needed:available:)` | `tryRead*`, `tryReadBytes`, `trySkip` |
| `invalidLength(_:)` | any throwing API given a negative `length: Int` |

Non-throwing counterparts treat a negative `length` as a failed read: `readBytes(length:)` and `peekBytes(at:length:)` return `nil`; `skip(_:)` returns `false`. They never trap.

Trapping (precondition failure) is reserved for:
- Internal integer overflow during growth.
- Internal arithmetic on lengths derived from trusted internal state.

User-supplied lengths and offsets never trap — they surface through `BytesError`.

---

## 7. Sendable & Concurrency

| Type | Sendable | Notes |
|---|---|---|
| `Bytes` | yes | Immutable view; ARC is atomic. |
| `BytesStorage` | `@unchecked Sendable` | Internal; mutation only via `BytesMut`, which CoWs if shared. |
| `BytesMut` | no | Unique-mutation semantics; sending across actors defeats CoW. |
| `BytesReader` | no, `~Copyable` | Cursor stays on one task. |
| `Endianness`, `BytesError` | yes | Plain enums. |

No locks. No actors. No `swift-atomics`. The only synchronization is class ARC (atomic by language guarantee) plus `isKnownUniquelyReferenced` (atomic at the language level).

---

## 8. Testing Strategy

Five test files, one per public surface piece, plus a CoW correctness file. Swift Testing (`@Test`/`#expect`).

### `BytesTests.swift`
- Construction: `Bytes()`, `Bytes([0xDE, 0xAD])`, `[0xDE, 0xAD] as Bytes`.
- `count`, `isEmpty`, `RandomAccessCollection` conformance (iteration, `first`, `last`, `contains`, `bytes[2..<4]`).
- `prefix`, `suffix`, `dropFirst`, `dropLast` — including over-large `n` (clamps), zero `n` (identity), empty source.
- Every `peek*` × `.big`/`.little`/`.host` × edge offsets × short buffers; assert `nil` past the end.
- Every `tryPeek*` throws `BytesError.outOfBounds` with correct fields.
- `withUnsafeBytes` exposes the right pointer/length even after slicing (offset is applied).

### `BytesMutTests.swift`
- Construction: default, with capacity, from sequence.
- `count`/`capacity` after `reserveCapacity`, after appends, after `clear`.
- Each `put*` × endianness produces an exact byte pattern (assert equality against literal `Bytes`).
- `putBytes(_: Bytes)` and `putBytes(_: Sequence)`.
- Growth: append past initial capacity; assert `capacity` doubled and content preserved.
- `freeze()` returns the right contents and resets the builder to empty.
- `withUnsafeMutableBytes` allows in-place patching.

### `BytesReaderTests.swift`
- `remaining`/`consumed`/`isExhausted` track correctly across reads.
- `read*` advances on success; returns `nil` and does not advance on short read (assert `remaining` unchanged).
- `tryRead*` throws `BytesError.shortRead(needed:available:)` with correct fields.
- `readBytes(length:)` returns a zero-copy slice (verify start address via `withUnsafeBytes`).
- `skip`/`trySkip` past the end behaves correctly.
- `remainingBytes()` is non-advancing and reflects the unread tail.
- `~Copyable` enforcement: smoke test ensuring consume/borrow patterns compile.

### `EndiannessTests.swift`
- Round-trip every integer width through `put*` → `read*` for `.big`/`.little`/`.host`.
- Assert exact byte order against hex literals — first test that fails if `loadFixed`/`storeFixed` regress.

### `CowTests.swift`
- `BytesMut` → `freeze()` → builder mutated again: original `Bytes` unchanged.
- `BytesMut.snapshot()` → mutate `BytesMut`: snapshot still equals the pre-mutation prefix; verify a real copy occurred (start-address differs after CoW).
- Two `Bytes` from the same `freeze()` share storage (same start address); slicing one doesn't disturb the other.
- Stress: 10,000 append/snapshot/mutate cycles under `swift test --sanitize=address` to flush leaks/double-frees.

**Coverage target:** > 90% line coverage on `Sources/Bytes`, validated by `swift test --enable-code-coverage`.

---

## 9. Deferrals

Each becomes its own design later, in roughly this order:

1. Hex / Base64 codecs (Layer 1, T1).
2. Varints (LEB128, ZigZag) (Layer 1, T1).
3. UUID (Layer 1, T1) — depends on Layer 6 RNG.
4. BitSet / OptionSet helpers (Layer 1, T1).
5. Percent encoding / form encoding (Layer 1, T1).
6. SIMD UTF-8 validation (Layer 1, T2) — depends on a SIMD strategy.
7. URL/URI parser + IDNA (Layer 1, T3) — depends on Layer 2 Unicode tables.
8. COBS, tagged pointers, structural zero-copy views (Layer 1, T1–T2).

Explicitly deferred indefinitely:
- Foundation `Data` interop.
- `Codable` conformance (Layer 14).
- Async streaming reads (Layer 11).

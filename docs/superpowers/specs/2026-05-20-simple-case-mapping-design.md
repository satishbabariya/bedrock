# Simple Case Mapping Design (Layer 2.3)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1 (UCD codegen, `TwoStageTrie`), Layer 2.2 (extended `UCDEntry` + multi-property `main.swift`)
**Date:** 2026-05-20

## Purpose

Add scalar-level simple case mapping (UCD fields 12/13/14) to `UnicodeProperties`. Three new entry points return the simple uppercase, lowercase, or titlecase mapping for an input `Unicode.Scalar`. For codepoints with no mapping (the vast majority), the input scalar is returned unchanged.

This sub-project also generalizes the codegen pipeline beyond `UInt8` values: case mappings store target codepoints (`UInt32`). `TwoStageTrie`, `BuiltTrie`, `TwoStageTrieBuilder`, and `CodeEmitter` all become generic over the value type.

## Scope

### In scope (v1)

- **Extended `UCDEntry`** with `simpleUppercase: UInt32`, `simpleLowercase: UInt32`, `simpleTitlecase: UInt32`. Value `0` means "no mapping; return input scalar".
- **Extended parser** to extract fields 12/13/14 as hex codepoints (empty → 0).
- **Three new `Array<UCDEntry>` expansion helpers**: `expandSimpleUppercase()`, `expandSimpleLowercase()`, `expandSimpleTitlecase()`, each returning `[UInt32]`.
- **Generic `BuiltTrie<Value>`, `TwoStageTrieBuilder.build<Value>`, `CodeEmitter.emit<Value>`** parameterized on the value type. Existing `UInt8` call sites work unchanged via Swift's generic inference.
- **`CodeEmitter.emit` gains a `valueTypeName: String` parameter** so the emitted Swift source can spell `TwoStageTrie<UInt32>` instead of the hardcoded `TwoStageTrie<UInt8>`.
- **Three new generated table files**: `SimpleUppercaseTable.swift`, `SimpleLowercaseTable.swift`, `SimpleTitlecaseTable.swift`. Each is a `TwoStageTrie<UInt32>`.
- **Three new entry points** on `UnicodeProperties`: `simpleUppercase(of:)`, `simpleLowercase(of:)`, `simpleTitlecase(of:)`. Each returns `Unicode.Scalar`.
- Stdlib-only at runtime; Foundation in codegen as before.

### Out of scope (separate work when needed)

- **`SpecialCasing.txt`** — locale-dependent (Turkish dotted/dotless I), context-dependent (Greek final sigma), and multi-codepoint cases (ß→SS, ﬃ→FFI, etc.). Substantial format complexity; own sub-project.
- **`CaseFolding.txt`** — separate property for case-insensitive comparison. Own sub-project.
- **`toUpper(_: String)` / `toLower(_: String)`** — string-level case conversion. v1 stays scalar-level.
- **Title-casing words / sentences** — needs UAX #29 segmentation.
- **`DerivedCoreProperties.txt` flags** (`Uppercase`, `Lowercase`, `Cased`, `Case_Ignorable`). Own sub-project.

## Module Layout (additions / modifications)

```
Sources/UnicodeProperties/
├── SimpleCaseMapping.swift                       # new: three entry points
└── Generated/
    ├── GeneralCategoryTable.swift                # existing
    ├── BidiClassTable.swift                      # existing
    ├── CanonicalCombiningClassTable.swift        # existing
    ├── SimpleUppercaseTable.swift                # new (codegen)
    ├── SimpleLowercaseTable.swift                # new (codegen)
    └── SimpleTitlecaseTable.swift                # new (codegen)

Sources/UnicodeProperties/Internal/
└── TwoStageTrie.swift                            # generic over Value

Sources/BedrockUcdGen/
├── UCDParser.swift                               # extend UCDEntry + 3 new expansion helpers
├── TwoStageTrieBuilder.swift                     # generic over Value
└── CodeEmitter.swift                             # generic over Value + valueTypeName parameter
```

```
Tests/UnicodePropertiesTests/
└── SimpleCaseMappingTests.swift                  # new (spot-checks)

Tests/BedrockUcdGenTests/
├── ExpandSimpleCaseTests.swift                   # new (expansion-helper tests)
└── TwoStageTrieBuilderTests.swift                # extended: one UInt32 test
```

## Public API

```swift
extension UnicodeProperties {

    /// Simple uppercase mapping (UnicodeData.txt field 12).
    /// Returns the input scalar unchanged when no mapping exists.
    ///
    /// "Simple" = single-codepoint mapping only. Multi-codepoint cases
    /// (e.g., "ß" → "SS") and locale-dependent cases (Turkish dotted/
    /// dotless I) require SpecialCasing.txt; that's a separate sub-project.
    @inlinable
    public static func simpleUppercase(of scalar: Unicode.Scalar) -> Unicode.Scalar

    /// Simple lowercase mapping (UnicodeData.txt field 13).
    @inlinable
    public static func simpleLowercase(of scalar: Unicode.Scalar) -> Unicode.Scalar

    /// Simple titlecase mapping (UnicodeData.txt field 14).
    @inlinable
    public static func simpleTitlecase(of scalar: Unicode.Scalar) -> Unicode.Scalar
}
```

**Storage convention:** `0` in the trie means "no mapping; return input scalar". Any nonzero value is the target codepoint:

```swift
let raw = simpleUppercaseTable.lookup(scalar.value)
return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
```

The `?? scalar` fallback is unreachable by construction (every emitted value is a valid codepoint) but satisfies `Unicode.Scalar(_: UInt32)`'s optional signature.

## Codegen Changes

### Extended `UCDEntry`

```swift
public struct UCDEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let category: String
    public let canonicalCombiningClass: UInt8
    public let bidiClass: String
    public let simpleUppercase: UInt32   // new — 0 = identity
    public let simpleLowercase: UInt32   // new — 0 = identity
    public let simpleTitlecase: UInt32   // new — 0 = identity

    public init(first: UInt32, last: UInt32, category: String,
                canonicalCombiningClass: UInt8 = 0,
                bidiClass: String = "L",
                simpleUppercase: UInt32 = 0,
                simpleLowercase: UInt32 = 0,
                simpleTitlecase: UInt32 = 0)
}
```

The defaults on the new params let synthetic test inputs stay terse.

### Parser additions

After the existing field extraction:

```swift
let upper = fields[12].isEmpty ? 0 : UInt32(fields[12], radix: 16) ?? 0
let lower = fields[13].isEmpty ? 0 : UInt32(fields[13], radix: 16) ?? 0
let title = fields[14].isEmpty ? 0 : UInt32(fields[14], radix: 16) ?? 0
```

Pass these to both `entries.append(UCDEntry(...))` call sites.

### Generic trie infrastructure

`Sources/UnicodeProperties/Internal/TwoStageTrie.swift` (already generic, no change needed):
```swift
internal struct TwoStageTrie<Value: FixedWidthInteger>: Sendable
    where Value: Sendable
```

`Sources/BedrockUcdGen/TwoStageTrieBuilder.swift` (generalize):
```swift
public struct BuiltTrie<Value: FixedWidthInteger & Sendable>: Sendable {
    public let stage1: [UInt16]
    public let stage2: [Value]
    public init(stage1: [UInt16], stage2: [Value])
    public func lookup(_ codepoint: UInt32) -> Value
}

public enum TwoStageTrieBuilder {
    public static func build<Value: FixedWidthInteger & Sendable>(
        _ uncompacted: [Value]
    ) -> BuiltTrie<Value>
}
```

Block-dedup logic uses the array contents as a `Hashable` key — works for any `FixedWidthInteger` element type.

`Sources/BedrockUcdGen/CodeEmitter.swift` (generalize + add valueTypeName):
```swift
public enum CodeEmitter {
    public static func emit<Value: FixedWidthInteger & Sendable>(
        _ trie: BuiltTrie<Value>,
        unicodeVersion: String,
        globalName: String,
        valueTypeName: String
    ) -> String
}
```

Existing `UInt8` call sites must add `valueTypeName: "UInt8"`. Three new `UInt32` call sites pass `valueTypeName: "UInt32"`.

### Three new expansion helpers

```swift
public extension Array where Element == UCDEntry {
    func expandSimpleUppercase() -> [UInt32] {
        var out = [UInt32](repeating: 0, count: 0x110000)
        for entry in self where entry.simpleUppercase != 0 {
            for cp in entry.first...entry.last {
                out[Int(cp)] = entry.simpleUppercase
            }
        }
        return out
    }
    func expandSimpleLowercase() -> [UInt32]   // analogous
    func expandSimpleTitlecase() -> [UInt32]   // analogous
}
```

None of these throw — there's no abbreviation lookup; the value is already a codepoint.

### `main.swift` extension

The current single-loop iterates over a tuple list of `(path, name, label, expand)` where every `expand` produces `[UInt8]`. Adding `UInt32` outputs makes the heterogeneous-tuple typing awkward.

Solution: **two sequential loops**. One for `UInt8` properties (3 entries), one for `UInt32` properties (3 entries). Slight duplication, much simpler types.

## Edge Cases

| Case | Handling |
|---|---|
| Codepoint not in UCD | All three case fields default to 0 → identity. ✓ |
| ASCII `"A"` (U+0041) | upper=empty, lower=`0061`, title=empty. `simpleLowercase` returns `"a"`; others return identity. |
| Titlecase letter `"ǅ"` (U+01C5) | upper=`01C4`, lower=`01C6`, title=empty. Three different outputs from the three entry points. |
| Sharp s `"ß"` (U+00DF) | upper=empty (multi-codepoint case is in `SpecialCasing.txt`). `simpleUppercase` returns identity in v1. Documented. |
| Greek capital sigma `"Σ"` | lower=`03C3` (σ). Context-dependent final-sigma rule (`U+03C2`) is `SpecialCasing.txt` territory. |
| Turkish I (U+0130 / U+0131) | Non-Turkish-locale mappings only. Turkish-locale rules are `SpecialCasing.txt`. |
| CJK / Hangul / Tangut ranges | All three case fields empty in compressed range markers. Range expansion fills with 0 (identity). ✓ |
| Range entry with a mapping | None exist in `UnicodeData.txt`. Confirmed by inspection. |

## Testing Strategy

### `UnicodePropertiesTests/SimpleCaseMappingTests.swift`
- ASCII bidirectional pairs (A↔a, Z↔z) and identity sanity (A→A uppercase identity).
- ASCII non-letters (digits, spaces, punctuation) all identity for all three mappings.
- Titlecase letter U+01C5 distinct results for all three.
- Latin-1 supplement: À↔à, Ø↔ø.
- Greek capital sigma → lowercase σ.
- CJK identity (U+6F22).
- ß identity for uppercase (multi-codepoint mapping deferred).
- Round-trip is *not* asserted: case mapping is not a clean inverse for many codepoints.

### `BedrockUcdGenTests/ExpandSimpleCaseTests.swift`
- Empty entries → all-zero 0x110000-element arrays.
- Single entry with explicit uppercase mapping populates exactly that codepoint.
- Single entry with empty mapping field stays at zero.
- Range entry leaves the entire range at zero (since range entries don't carry case mappings in practice).

### Extended `TwoStageTrieBuilderTests.swift`
- One new test: `builderHandlesUInt32` — builds a trie from a `[UInt32]` input, verifies lookups. Confirms the generic instantiation works alongside existing `UInt8` tests.

### Extended `ExhaustiveTests.swift`
- For every Unicode scalar, call all three new entry points. Soft assertion: no trap; result is a valid `Unicode.Scalar` (guaranteed by the entry-point fallback). Adds ~3 × 1.1M = 3.3M lookups; should remain under 2s.

## Non-Functional Requirements

- **Stdlib only** at runtime. Foundation only in `bedrock-ucd-gen` (existing exception).
- **O(1) lookup** for all three new entry points.
- **Constant-time everywhere.**
- **Sendable** end-to-end.
- **No new file-format complexity.** Three new properties come from existing `UnicodeData.txt` fields.
- **Backward-compatible generic refactor.** Existing `UInt8` call sites work unchanged because Swift's type inference picks the right `Value`.

## Open Questions

None. All resolved during brainstorming:
- Three properties bundled together (same UCD source, same shape).
- Value type: `UInt32` (need full codepoint range).
- Storage convention: `0` = identity. No need for `Optional` or a sentinel beyond zero.
- Generic refactor: extend `BuiltTrie`, `TwoStageTrieBuilder.build`, `CodeEmitter.emit`. Existing call sites adapt via Swift inference; explicit `valueTypeName` needed in the emit signature so the output Swift compiles.
- `main.swift` shape: two sequential loops (one per element type) — simpler than a heterogeneous tuple.

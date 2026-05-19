# UnicodeProperties Module Design (Layer 2.1)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** stdlib only (no Layer 1 modules)
**Date:** 2026-05-19

## Purpose

Bring up Layer 2 by establishing two things:

1. A **UCD codegen pipeline** (`bedrock-ucd-gen` executable target) that ingests vendored Unicode Character Database files and emits compact Swift lookup tables.
2. A first **`UnicodeProperties`** library that consumes those tables to expose O(1) general-category lookup for every Unicode scalar.

This is the entry point for everything table-heavy in Layer 2. Subsequent sub-projects (normalization, segmentation, case mapping, bidi, additional properties) all reuse the same codegen infrastructure and the same two-stage trie primitive.

## Scope

### In scope (v1)

- **Codegen tool** (`bedrock-ucd-gen`): SwiftPM executable target. Reads `Sources/UnicodeProperties/UCD/UnicodeData.txt` (vendored Unicode 16.0). Emits `Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift`. Stdlib-only.
- **`UnicodeProperties` library**: namespace + `GeneralCategory` enum + lookup + major-category helpers + `unicodeVersion` constant.
- **Two-stage trie primitive** (`TwoStageTrie<Value: FixedWidthInteger>`) — generic over the value type, reused by future property tables.
- **Vendored data**: `UnicodeData.txt` (~1.8 MB) checked into the repo at `Sources/UnicodeProperties/UCD/UnicodeData.txt` so codegen is reproducible without network.
- **Pre-generated tables checked in**: `swift build` works without running codegen.
- **Compressed-range handling** for the 19 `<X, First>`/`<X, Last>` pairs in Unicode 16.0 (CJK Ideograph + Extensions A–I, Hangul Syllable, Tangut + Supplement, three surrogate ranges, BMP/Plane-15/Plane-16 PUAs).
- **Codegen-time correctness check**: after building the trie, verify every codepoint's `trie.lookup(cp)` matches the uncompacted source. Fail loudly before emitting.

### Out of scope (subsequent Layer 2 sub-projects)

- **Other Unicode properties** — bidi class, script, name, numeric value, age, block, joining type, line break class, decomposition, casefolding. Each layered onto this codegen pipeline as a separate output. Lands in 2.2.
- **Property aliases / string-name lookup** (e.g., `"Lu"` → `.uppercaseLetter`). Easy to add later.
- **Multi-version UCD** — pin to 16.0; bump via codegen rerun.
- **Network fetching** of UCD files. Vendor the bytes.
- **CodepointSet / range iteration** — separate primitive.
- **3-stage tries / BMP-only tables** / fancier compaction — the 2-stage trie comes in under 100 KB of source for one property; that's already small.
- **`CustomStringConvertible` on `GeneralCategory`** — defer until a use case asks.
- **`@inlinable` perf tuning** beyond what the spec already provides (lookup is `@inlinable`; that's enough for v1).

## Repository Layout

```
Sources/
├── UnicodeProperties/                       # library target
│   ├── UnicodeProperties.swift             # namespace + entry points
│   ├── GeneralCategory.swift               # enum + major-category helpers
│   ├── Internal/
│   │   └── TwoStageTrie.swift              # lookup primitive
│   ├── Generated/
│   │   └── GeneralCategoryTable.swift      # codegen output (checked in)
│   └── UCD/
│       └── UnicodeData.txt                 # vendored, Unicode 16.0.0
└── bedrock-ucd-gen/                         # executable target
    ├── main.swift                          # CLI entry
    ├── UCDParser.swift                     # parses UnicodeData.txt
    ├── TwoStageTrieBuilder.swift           # compacts to 2-stage trie
    └── CodeEmitter.swift                   # emits Swift source

Tests/
├── UnicodePropertiesTests/
│   ├── GeneralCategoryTests.swift          # spot-check well-known codepoints
│   ├── MajorCategoryHelperTests.swift      # isLetter, isNumber, etc.
│   ├── BoundaryTests.swift                 # range boundaries, surrogates
│   ├── RangedEntryTests.swift              # CJK / Hangul / Tangut ranges
│   └── ExhaustiveTests.swift               # all codepoints don't crash
└── BedrockUcdGenTests/
    ├── UCDParserTests.swift
    ├── TwoStageTrieBuilderTests.swift
    └── CodeEmitterTests.swift
```

## Public API

```swift
public enum UnicodeProperties {

    /// Unicode general category (UnicodeData.txt field 3, UAX #44 table 12).
    ///
    /// Raw values are stable; do not rely on their numeric ordering.
    public enum GeneralCategory: UInt8, Sendable, Hashable, CaseIterable {
        case uppercaseLetter        = 0   // Lu
        case lowercaseLetter        = 1   // Ll
        case titlecaseLetter        = 2   // Lt
        case modifierLetter         = 3   // Lm
        case otherLetter            = 4   // Lo
        case nonspacingMark         = 5   // Mn
        case spacingMark            = 6   // Mc
        case enclosingMark          = 7   // Me
        case decimalNumber          = 8   // Nd
        case letterNumber           = 9   // Nl
        case otherNumber            = 10  // No
        case connectorPunctuation   = 11  // Pc
        case dashPunctuation        = 12  // Pd
        case openPunctuation        = 13  // Ps
        case closePunctuation       = 14  // Pe
        case initialPunctuation     = 15  // Pi
        case finalPunctuation       = 16  // Pf
        case otherPunctuation       = 17  // Po
        case mathSymbol             = 18  // Sm
        case currencySymbol         = 19  // Sc
        case modifierSymbol         = 20  // Sk
        case otherSymbol            = 21  // So
        case spaceSeparator         = 22  // Zs
        case lineSeparator          = 23  // Zl
        case paragraphSeparator     = 24  // Zp
        case control                = 25  // Cc
        case format                 = 26  // Cf
        case surrogate              = 27  // Cs
        case privateUse             = 28  // Co
        case unassigned             = 29  // Cn (default for absent codepoints)
    }

    /// O(1) general-category lookup. Returns `.unassigned` for codepoints
    /// not assigned in Unicode 16.0.
    public static func generalCategory(of scalar: Unicode.Scalar) -> GeneralCategory

    // Major-category helpers
    public static func isLetter(_ scalar: Unicode.Scalar) -> Bool       // L*
    public static func isNumber(_ scalar: Unicode.Scalar) -> Bool       // N*
    public static func isMark(_ scalar: Unicode.Scalar) -> Bool         // M*
    public static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool  // P*
    public static func isSymbol(_ scalar: Unicode.Scalar) -> Bool       // S*
    public static func isSeparator(_ scalar: Unicode.Scalar) -> Bool    // Z*
    public static func isControl(_ scalar: Unicode.Scalar) -> Bool      // C*

    /// The Unicode version these tables were generated from.
    public static let unicodeVersion: String = "16.0.0"
}
```

### Internal lookup primitive

```swift
// Sources/UnicodeProperties/Internal/TwoStageTrie.swift

@usableFromInline
internal struct TwoStageTrie<Value: FixedWidthInteger> {
    @usableFromInline let stage1: [UInt16]   // 4352 entries
    @usableFromInline let stage2: [Value]    // N × 256 (deduplicated blocks)

    @inlinable
    func lookup(_ codepoint: UInt32) -> Value {
        let block = Int(stage1[Int(codepoint >> 8)])
        return stage2[(block << 8) | Int(codepoint & 0xFF)]
    }
}
```

### Generated table shape

```swift
// Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift
// GENERATED by `swift run bedrock-ucd-gen`. Do not edit by hand.
// Source: Sources/UnicodeProperties/UCD/UnicodeData.txt (Unicode 16.0.0)

@usableFromInline
internal let generalCategoryTable = TwoStageTrie<UInt8>(
    stage1: [ /* 4352 UInt16 entries */ ],
    stage2: [ /* N × 256 UInt8 entries (deduplicated blocks) */ ]
)
```

### Codegen CLI

```
$ swift run bedrock-ucd-gen
Reading Sources/UnicodeProperties/UCD/UnicodeData.txt ...
Parsed 34924 codepoint entries (Unicode 16.0.0).
Expanded ranges: 7 compressed range pairs handled.
Built two-stage trie: 4352 stage1 + 47 unique blocks (12032 bytes stage2).
Self-check: 1114112 codepoints round-trip ✓
Wrote Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift (24531 bytes).
```

No CLI flags in v1. Hard-coded relative paths; must be run from repo root.

## Codegen Algorithm

### Parsing `UnicodeData.txt`

Each line is `;`-separated with 15 fields. We care about field 0 (codepoint hex), field 1 (name — to detect range markers), and field 2 (general category abbreviation):

```
0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
```

**Compressed range handling.** Two adjacent lines bracketing a contiguous run:

```
4E00;<CJK Ideograph, First>;Lo;...
9FFF;<CJK Ideograph, Last>;Lo;...
```

Parser detects names ending in `, First>` and consumes the next line (ending in `, Last>`) to recover the inclusive range. Unicode 16.0 has 19 such pairs: CJK Ideograph + Extensions A–I, Hangul Syllable, Tangut Ideograph + Supplement, the three surrogate ranges (High/High-PUA/Low), and the BMP/Plane-15/Plane-16 Private Use Areas.

**Absent codepoints** default to `.unassigned` (`Cn`).

### Building the trie

```
1. allocate uncompactedTable[0x110000], all = .unassigned (raw 29)
2. for each parsed entry / expanded range:
       uncompactedTable[codepoint(s)] = generalCategory
3. split into 4352 blocks of 256 entries each
4. for each block:
       if identical to an already-seen block → reuse blockIndex
       else                                    → append to stage2, allocate new blockIndex
       stage1[blockNumber] = blockIndex
5. self-check: for every codepoint 0..0x10FFFF,
       assert trie.lookup(cp) == uncompactedTable[cp]
6. emit Swift literals
```

### Expected output sizes (Unicode 16.0)

- `stage1`: 4352 × `UInt16` = **8.7 KB** (~50–60 KB as Swift source).
- `stage2`: ~40–60 unique blocks × 256 × `UInt8` = **10–15 KB** (~40 KB as Swift source).
- **Total emitted source**: ~80–100 KB.
- **Compiled static data**: ~20–25 KB.

## Edge Cases

| Case | Handling |
|---|---|
| Codepoint 0x0000 | `Cc` (control). Falls out of the trie correctly. |
| Surrogates U+D800..U+DFFF | UCD lists them as `Cs`. `Unicode.Scalar` can't represent them, so the public entry never sees them; verified at the trie layer via raw `UInt32` lookup in tests. |
| Compressed range first/last | Parser fills `[first, last]` inclusive. Tested at the endpoints and midpoints. |
| Codepoints past U+10FFFF | `Unicode.Scalar.init(_:UInt32)` returns nil; entry never sees them. |
| Lone `Cn` codepoints (e.g., U+0378) | Absent from UCD → `.unassigned` via the deduplicated all-Cn block. |
| Trie value type | `UInt8` (30 categories ≤ 255 values). |
| Stage1 entry type | `UInt16` — capacity well above the ~50 unique blocks we'll use. |

## Testing Strategy

Each test file targets ≥ 90% line coverage on its corresponding source file.

### `UnicodePropertiesTests/GeneralCategoryTests.swift` — spot-checks
- ASCII letters/digits/symbols: `"A"` → `.uppercaseLetter`, `"z"` → `.lowercaseLetter`, `"5"` → `.decimalNumber`, `"!"` → `.otherPunctuation`, `" "` → `.spaceSeparator`, `"\t"` → `.control`.
- Latin-1 supplement: `"À"` (U+00C0) → `.uppercaseLetter`.
- Greek titlecase: `"ǅ"` (U+01C5) → `.titlecaseLetter`.
- Combining marks: `"\u{0301}"` → `.nonspacingMark`.
- CJK: `"漢"` (U+6F22) → `.otherLetter`.
- Hangul syllables: `"한"` (U+D55C) → `.otherLetter`.
- Mathematical symbols: `"∑"` (U+2211) → `.mathSymbol`, `"+"` (U+002B) → `.mathSymbol`.
- Currency: `"$"` (U+0024) → `.currencySymbol`, `"€"` (U+20AC) → `.currencySymbol`.
- Emoji: `"😀"` (U+1F600) → `.otherSymbol`.
- Private use: `Unicode.Scalar(0xE000)!` → `.privateUse`.
- Format: `Unicode.Scalar(0x200B)!` (ZWSP) → `.format`.

### `MajorCategoryHelperTests.swift`
- Each helper exercised with positive + negative cases (see spot-checks above).
- `isControl("\t")` true; `isSeparator(" ")` true; `isSeparator("\n")` false (newline is `Cc`, not `Z*`).

### `BoundaryTests.swift`
- Last ASCII (U+007F, `Cc`).
- First Latin-1 supplement (U+0080, `Cc`).
- Last valid scalar (U+10FFFF, `.privateUse` in Plane 16 PUA range).
- BMP PUA range bounds (U+E000, U+F8FF).
- One codepoint before and after each `<X, First>`/`<X, Last>` range pair.

### `RangedEntryTests.swift`
- U+4E00, U+5000 (middle), U+9FFF — all `.otherLetter` (CJK Ideograph).
- U+AC00 (first Hangul syllable), U+D7A3 (last) — `.otherLetter`.
- U+F0000, U+FFFFD — `.privateUse` (Plane 15 PUA).
- U+17000, U+187F7 — `.otherLetter` (Tangut Ideograph).

### `ExhaustiveTests.swift`
- For every `cp in 0..<0x110000`: if `Unicode.Scalar(cp)` is non-nil, call `generalCategory(of:)`. Assert the call doesn't trap and the returned raw value is in 0...29.
- ~1.1 million lookups; expected runtime well under a second.

### `BedrockUcdGenTests/UCDParserTests.swift`
- Parse a 3-line synthetic input including one range pair.
- Reject malformed lines (e.g., too few fields, unknown category abbreviation).

### `BedrockUcdGenTests/TwoStageTrieBuilderTests.swift`
- Build from a hand-built uncompacted array; verify `lookup(cp)` matches input for every entry.
- Verify block deduplication: an input of all-zeros produces stage2 of exactly 256 entries.

### `BedrockUcdGenTests/CodeEmitterTests.swift`
- Emit a tiny trie; parse the emitted Swift back into a string and verify structural properties (contains expected literals).

(The codegen tool's internal types are exposed for testing via a thin internal library target shared with the executable, or via `@testable import`.)

## Non-Functional Requirements

- **Stdlib only.** No Foundation. No swift-system. No swift-atomics. The codegen tool parses with `String.split(separator:)`.
- **Reproducible build.** Pre-generated tables checked in; `swift build` works without running codegen.
- **Reproducible codegen.** UCD source vendored; `swift run bedrock-ucd-gen` is deterministic.
- **O(1) lookup at runtime.** Two array indices, branchless.
- **Constant-time everywhere.** No allocations in the public lookup path.
- **Sendable.** Static tables; entire API is trivially `Sendable`.

## Open Questions

None. All resolved during brainstorming:
- Codegen split: separate executable target, not a build plugin (simpler, no SwiftPM plugin complexity).
- Vendor strategy: check in both raw UCD source and generated tables.
- Compaction scheme: 2-stage trie with block deduplication (ICU-standard).
- Other properties: deferred to 2.2 — same pipeline, separate outputs.
- Network access: none.

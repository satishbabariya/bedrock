# Bidi Class + Canonical Combining Class Design (Layer 2.2)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1 (`UnicodeProperties` library, `bedrock-ucd-gen` executable, `TwoStageTrie` primitive, `UCDEntry` parser)
**Date:** 2026-05-20

## Purpose

Extend the Layer 2.1 codegen pipeline to support two additional `UnicodeData.txt` properties:

1. **Bidi class** (field 4) — required by Layer 2.7 (UAX #9 bidirectional algorithm).
2. **Canonical combining class** (field 3) — required by Layer 2.3 (Unicode normalization).

Both are single-byte-per-codepoint properties that fit into the existing `TwoStageTrie<UInt8>` infrastructure. This sub-project demonstrates that adding a new property is a small, mechanical extension once the codegen pipeline is in place.

## Scope

### In scope (v1)

- **Extended `UCDEntry`** carrying `canonicalCombiningClass: UInt8` and `bidiClass: String`.
- **Extended `UCDParser`** to extract fields 3 and 4 from each line.
- **`BidiClassCode.rawValue(for:)`** mapping the 23 UAX #9 abbreviations to `UInt8`.
- **Three independent uncompacted-array expansions** (general category, bidi class, CCC).
- **Three independent tries** built and self-checked at codegen time.
- **Extended `CodeEmitter`** taking a global name so multiple table files don't collide.
- **Three generated files**: `GeneralCategoryTable.swift` (unchanged), `BidiClassTable.swift` (new), `CanonicalCombiningClassTable.swift` (new).
- **`UnicodeProperties.BidiClass` enum** with all 23 UAX #9 values.
- **`UnicodeProperties.bidiClass(of:)`** O(1) entry point.
- **`UnicodeProperties.canonicalCombiningClass(of:)`** O(1) entry point returning `UInt8`.
- Compressed-range handling already correct — range pairs in UCD have uniform CCC and bidi class.
- Stdlib-only at runtime; Foundation in codegen tool only.

### Out of scope (separate work when needed)

- **`DerivedBidiClass.txt`** — would give correct defaults for unassigned codepoints (R/AL/ET rather than L). Add later if Layer 2.7's bidi algorithm needs it.
- **Numeric type/value** (fields 6/7/8) — separate decision, separate codegen output.
- **Simple case mappings** (fields 12/13/14) — Layer 2.5's problem.
- **Decomposition mapping** (field 5) — Layer 2.3's problem; format complexity (compatibility tags, multi-codepoint).
- **Scripts** — separate UCD file (`Scripts.txt`).
- **DerivedCoreProperties** — separate UCD file.
- **Property aliases / string-name parsing** for the enums.
- **`CustomStringConvertible` on `BidiClass`** — emit the UCD abbreviation. Defer.
- **Strongly-typed CCC enum** — UInt8 is what callers want for canonical sorting; enum would be a UI nicety only.

## Module Layout (additions)

```
Sources/UnicodeProperties/
├── BidiClass.swift                          # new: BidiClass enum + entry point
├── CanonicalCombiningClass.swift            # new: canonicalCombiningClass entry point
└── Generated/
    ├── GeneralCategoryTable.swift           # existing (unchanged)
    ├── BidiClassTable.swift                 # new (codegen output)
    └── CanonicalCombiningClassTable.swift   # new (codegen output)

Sources/BedrockUcdGen/
├── UCDParser.swift                          # extended: extract fields 3 & 4, add BidiClassCode
├── TwoStageTrieBuilder.swift                # unchanged (already generic)
└── CodeEmitter.swift                        # extended: emit takes globalName parameter
```

```
Tests/UnicodePropertiesTests/
├── BidiClassTests.swift                     # spot-checks
├── BidiClassConformanceTests.swift          # CaseIterable, raw-value sanity
└── CanonicalCombiningClassTests.swift       # spot-checks

Tests/BedrockUcdGenTests/
└── BidiClassCodeTests.swift                 # abbreviation → raw-value map
```

## Public API

```swift
extension UnicodeProperties {

    /// Unicode bidirectional class (UnicodeData.txt field 4, UAX #9).
    public enum BidiClass: UInt8, Sendable, Hashable, CaseIterable {
        // Strong
        case leftToRight                  = 0   // L
        case rightToLeft                  = 1   // R
        case arabicLetter                 = 2   // AL
        // Weak
        case europeanNumber               = 3   // EN
        case europeanSeparator            = 4   // ES
        case europeanTerminator           = 5   // ET
        case arabicNumber                 = 6   // AN
        case commonSeparator              = 7   // CS
        case nonspacingMark               = 8   // NSM
        case boundaryNeutral              = 9   // BN
        // Neutral
        case paragraphSeparator           = 10  // B
        case segmentSeparator             = 11  // S
        case whiteSpace                   = 12  // WS
        case otherNeutral                 = 13  // ON
        // Explicit formatting
        case leftToRightEmbedding         = 14  // LRE
        case leftToRightOverride          = 15  // LRO
        case rightToLeftEmbedding         = 16  // RLE
        case rightToLeftOverride          = 17  // RLO
        case popDirectionalFormat         = 18  // PDF
        case leftToRightIsolate           = 19  // LRI
        case rightToLeftIsolate           = 20  // RLI
        case firstStrongIsolate           = 21  // FSI
        case popDirectionalIsolate        = 22  // PDI
    }

    /// O(1) bidi-class lookup. Defaults to `.leftToRight` for codepoints
    /// not present in UnicodeData.txt; refinements for unassigned-block
    /// defaults (R/AL/ET) await `DerivedBidiClass.txt` ingestion.
    @inlinable
    public static func bidiClass(of scalar: Unicode.Scalar) -> BidiClass

    /// O(1) canonical-combining-class lookup. Returns 0 for codepoints
    /// with no combining class (the default per UCD).
    ///
    /// Exposed as `UInt8` rather than a strongly-typed enum because
    /// canonical-ordering algorithms consume the value numerically.
    @inlinable
    public static func canonicalCombiningClass(of scalar: Unicode.Scalar) -> UInt8
}
```

## Codegen Extension

### Extended `UCDEntry`

```swift
public struct UCDEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let category: String             // existing (field 2)
    public let canonicalCombiningClass: UInt8   // new (field 3)
    public let bidiClass: String            // new (field 4)
}
```

The parser reads fields 0, 1, 2, 3 (parse as UInt8), 4 (string). Range markers still expand inclusively; the second line of a pair is consumed only to recover the `last` codepoint — the first line's CCC/bidi values are reused (UCD always agrees across the pair).

### Extended parser

```swift
guard let ccc = UInt8(fields[3]) else {
    throw UCDParseError.invalidCodepoint(lineNumber: lineNumber, raw: String(fields[3]))
}
let bidi = String(fields[4])
```

### `BidiClassCode`

```swift
public enum BidiClassCode {
    public static func rawValue(for abbreviation: String) throws -> UInt8 {
        switch abbreviation {
        case "L":   return 0
        case "R":   return 1
        case "AL":  return 2
        case "EN":  return 3
        case "ES":  return 4
        case "ET":  return 5
        case "AN":  return 6
        case "CS":  return 7
        case "NSM": return 8
        case "BN":  return 9
        case "B":   return 10
        case "S":   return 11
        case "WS":  return 12
        case "ON":  return 13
        case "LRE": return 14
        case "LRO": return 15
        case "RLE": return 16
        case "RLO": return 17
        case "PDF": return 18
        case "LRI": return 19
        case "RLI": return 20
        case "FSI": return 21
        case "PDI": return 22
        default:
            throw UCDParseError.invalidCodepoint(lineNumber: -1, raw: abbreviation)
        }
    }
}
```

### Extended expansion

Three parallel expansion methods on `[UCDEntry]`:

```swift
extension Array where Element == UCDEntry {
    func expandGeneralCategory() throws -> [UInt8]    // existing (renamed from expandToUncompacted)
    func expandBidiClass() throws -> [UInt8]          // new
    func expandCanonicalCombiningClass() -> [UInt8]   // new
}
```

`expandCanonicalCombiningClass()` does not throw because CCC values come from `UInt8(_:)` parsing in the parser, which already errored before getting here.

### Extended emitter

```swift
public static func emit(_ trie: BuiltTrie,
                        unicodeVersion: String,
                        globalName: String) -> String
```

The `globalName` parameter replaces the hardcoded `"generalCategoryTable"`. Each table file uses a distinct name (`generalCategoryTable`, `bidiClassTable`, `canonicalCombiningClassTable`).

### Extended `main.swift`

```
1. parse UnicodeData.txt → [UCDEntry]
2. expand to three uncompacted arrays (gc, bidi, ccc)
3. build three independent tries
4. self-check each (1.1M codepoints round-trip per property)
5. emit three files
```

## Edge Cases

| Case | Handling |
|---|---|
| Codepoints absent from UCD | bidi class defaults to `L`; CCC defaults to 0. Both match UCD baseline semantics for the codepoints we care about. |
| Surrogates / PUA | Explicit UCD entries with bidi class `L` and CCC 0. No special handling. |
| Compressed range markers | All 19 ranges share uniform CCC (always 0) and bidi class (mostly `L`, some `R`/`AL` for Hebrew/Arabic-flavored ranges if any — verified by codegen self-check). |
| CCC max value | Unicode 16 uses up to ~240. Fits `UInt8` trivially. |
| `BidiClass` raw-value collisions with `GeneralCategory` | No collision: they're distinct types. Both happen to use `UInt8` but in different enums. |

## Testing Strategy

Each test file targets ≥ 90% line coverage on its corresponding source file.

### `BidiClassTests.swift` — spot-checks
- `"A"` → `.leftToRight`.
- Hebrew letter `\u{05D0}` → `.rightToLeft`.
- Arabic letter `\u{0627}` → `.arabicLetter`.
- `"5"` → `.europeanNumber`.
- `" "` → `.whiteSpace`.
- Combining acute `\u{0301}` → `.nonspacingMark`.
- LRE `\u{202A}` → `.leftToRightEmbedding`.
- RLE `\u{202B}` → `.rightToLeftEmbedding`.
- PDF `\u{202C}` → `.popDirectionalFormat`.
- LRI `\u{2066}`, RLI `\u{2067}`, FSI `\u{2068}`, PDI `\u{2069}` → respective isolate classes.
- `"$"` → `.europeanTerminator`.
- `","` → `.commonSeparator`.
- `\u{2029}` (paragraph separator) → `.paragraphSeparator`.

### `CanonicalCombiningClassTests.swift` — spot-checks
- `"A"` → 0.
- Combining grave `\u{0300}` → 230.
- Combining acute `\u{0301}` → 230.
- Combining tilde `\u{0303}` → 230.
- Combining cedilla `\u{0327}` → 202.
- Hiragana voicing mark `\u{3099}` → 8.
- Hebrew Sheva `\u{05B0}` → 10.
- Arabic shadda `\u{0651}` → 33.

### `BidiClassConformanceTests.swift`
- `BidiClass.allCases.count == 23`.
- Raw values cover 0...22 with no gaps.
- `Hashable`, `Sendable`, `Equatable` smoke check.

### `BedrockUcdGenTests/BidiClassCodeTests.swift`
- All 23 abbreviations map to expected raw values.
- Unknown abbreviation throws.

### `BedrockUcdGenTests/ExpandToUncompactedTests.swift` (extended)
- After parsing a synthetic input with explicit CCC and bidi class, expansion produces correct values across the relevant codepoints.

### `ExhaustiveTests.swift` (extended)
- For every codepoint U+0000..U+10FFFF (excluding surrogates): `bidiClass(of:).rawValue <= 22`. CCC needs no range check (every `UInt8` is in range).

## Non-Functional Requirements

- **Stdlib only** at runtime. Foundation only in `bedrock-ucd-gen` (existing exception).
- **O(1) lookup** for both new entry points.
- **Constant-time everywhere.**
- **Sendable** end-to-end.
- **No new file-format complexity.** Both properties come from `UnicodeData.txt` we already vendor and parse.
- **Reuses 2.1 infrastructure.** No new internal types beyond `BidiClass`; the trie primitive is unchanged.

## Open Questions

None. All resolved during brainstorming:
- Property bundling: bidi class + CCC together to amortize codegen-extension overhead.
- CCC API shape: `UInt8`, not a strongly-typed enum.
- Bidi-class defaults: accept `L` for absent codepoints in v1; `DerivedBidiClass.txt` ingestion is a follow-up.
- Codegen emit: takes a `globalName` parameter so multiple tables can coexist.
- Self-check: separate per property; abort emit on any mismatch.

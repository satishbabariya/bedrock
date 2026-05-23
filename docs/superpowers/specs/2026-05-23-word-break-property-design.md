# Word Break Property Design (Layer 2.11)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1 (codegen pipeline), Layer 2.10 (GraphemeBreakProperty pattern)
**Date:** 2026-05-23
**Parallel batch:** runs alongside Layer 2.12 (SentenceBreakProperty) in a separate git worktree.

## Purpose

Ship the `Word_Break` property per UAX #29. Per-codepoint property table that an eventual word-segmentation algorithm will consume to find word boundaries.

## Scope

### In scope (v1)

- **Vendored `WordBreakProperty-16.0.0.txt`** at `Sources/UnicodeProperties/UCD/WordBreakProperty.txt` (~110 KB / 1516 lines / ~1402 data entries).
- **`WordBreakPropertyParser`** mirroring `GraphemeBreakPropertyParser` (range-based UCD format with `#`-comments). Use `wbp` prefix on private file-local helpers.
- **`UnicodeProperties.WordBreak` enum** with **19 cases** (18 explicit UCD values + `other` default).
- **`WordBreakCode.rawValue(for:)`** mapping strings to UInt8.
- **`Array<WordBreakPropertyEntry>.expandWordBreak()`** returning `[UInt8]`, default-filled `0` (Other).
- **Generated table** `WordBreakTable.swift` (`TwoStageTrie<UInt8>`).
- **Entry point** `UnicodeProperties.wordBreak(of: Unicode.Scalar) -> WordBreak`.
- Stdlib-only at runtime.

### Out of scope

- **UAX #29 word segmentation algorithm** — uses this property + break rules. Separate sub-project.
- **`Other_Default_Ignorable_Code_Point` adjustments**, emoji subclasses.

## Property values (per UCD 16.0)

18 distinct values present in the file (plus implicit `Other`):
- ALetter (679 entries)
- CR (1)
- Double_Quote (1)
- Extend (556)
- ExtendNumLet (7)
- Format (13)
- Hebrew_Letter (10)
- Katakana (19)
- LF (1)
- MidLetter (9)
- MidNum (12)
- MidNumLet (7)
- Newline (4)
- Numeric (79)
- Regional_Indicator (1)
- Single_Quote (1)
- WSegSpace (6)
- ZWJ (1)

Plus `Other` (default) = 19 enum cases.

## Module Layout

```
Sources/UnicodeProperties/
├── WordBreak.swift                              # new: enum + entry point
├── UnicodeProperties.swift                      # add wordBreak(of:)
└── Generated/
    └── WordBreakTable.swift                     # new (codegen)

Sources/BedrockUcdGen/
└── WordBreakPropertyParser.swift                # new
```

```
Tests/UnicodePropertiesTests/
├── WordBreakTests.swift                         # new
└── ExhaustiveTests.swift                        # extend (controller does, post-merge)

Tests/BedrockUcdGenTests/
├── WordBreakPropertyParserTests.swift           # new
└── ExpandWordBreakTests.swift                   # new
```

## Public API

```swift
extension UnicodeProperties {

    /// Word_Break property (UAX #29). Used by word-segmentation
    /// algorithms. Returns `.other` for codepoints not explicitly
    /// listed in `WordBreakProperty.txt`.
    public enum WordBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other              = 0   // XX (default)
        case cr                 = 1   // CR
        case lf                 = 2   // LF
        case newline            = 3   // Newline
        case extend             = 4   // Extend
        case zwj                = 5   // ZWJ
        case regionalIndicator  = 6   // Regional_Indicator
        case format             = 7   // Format
        case katakana           = 8   // Katakana
        case hebrewLetter       = 9   // Hebrew_Letter
        case aLetter            = 10  // ALetter
        case singleQuote        = 11  // Single_Quote
        case doubleQuote        = 12  // Double_Quote
        case midNumLet          = 13  // MidNumLet
        case midLetter          = 14  // MidLetter
        case midNum             = 15  // MidNum
        case numeric            = 16  // Numeric
        case extendNumLet       = 17  // ExtendNumLet
        case wSegSpace          = 18  // WSegSpace
    }

    /// O(1) Word_Break lookup.
    @inlinable
    public static func wordBreak(of scalar: Unicode.Scalar) -> WordBreak {
        let raw = wordBreakTable.lookup(scalar.value)
        return WordBreak(rawValue: raw) ?? .other
    }
}
```

## Codegen

Mirror Layer 2.10 exactly. `WordBreakPropertyEntry(first, last, value)`, range-based parsing with `#`-comment stripping and `wbp`-prefixed file-local helpers. `WordBreakCode.rawValue(for:)` maps 18 string values to UInt8 0-18 (Other=0 default + 18 explicit). Expansion fills with default 0.

## Edge Cases

| Case | Handling |
|---|---|
| ASCII letter `"A"` | `.aLetter`. |
| ASCII digit `"5"` | `.numeric`. |
| CR (U+000D) | `.cr`. |
| LF (U+000A) | `.lf`. |
| Newline characters (NEL, FF, LS, PS) | `.newline`. |
| ZWJ (U+200D) | `.zwj`. |
| Single quote `'` (U+0027) | `.singleQuote`. |
| Double quote `"` (U+0022) | `.doubleQuote`. |
| Hebrew letter (U+05D0) | `.hebrewLetter`. |
| Katakana | `.katakana`. |
| Regional Indicator | `.regionalIndicator`. |
| Codepoint absent from UCD | `.other`. |

## Testing

- `WordBreakPropertyParserTests.swift` — 8 tests (single + range + comments + 4 rejection cases).
- `ExpandWordBreakTests.swift` — 6 tests (default fill, single + range entries, unknown code).
- `WordBreakTests.swift` — spot-checks covering all 19 enum cases.

## Expected output size

Estimate ~30-50 unique trie blocks, ~25-45 KB generated source.

## Non-Functional Requirements

- Stdlib-only runtime.
- O(1) lookup, Sendable, constant-time.
- Reuses `TwoStageTrieBuilder`, `CodeEmitter`, `emitUInt8`.

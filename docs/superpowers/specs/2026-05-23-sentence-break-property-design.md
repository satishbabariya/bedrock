# Sentence Break Property Design (Layer 2.12)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1 (codegen pipeline), Layer 2.10 (GraphemeBreakProperty pattern)
**Date:** 2026-05-23
**Parallel batch:** runs alongside Layer 2.11 (WordBreakProperty) in a separate git worktree.

## Purpose

Ship the `Sentence_Break` property per UAX #29. Per-codepoint property table that an eventual sentence-segmentation algorithm will consume to find sentence boundaries.

## Scope

### In scope (v1)

- **Vendored `SentenceBreakProperty-16.0.0.txt`** at `Sources/UnicodeProperties/UCD/SentenceBreakProperty.txt` (~214 KB / 2987 lines / ~2898 data entries).
- **`SentenceBreakPropertyParser`** mirroring `GraphemeBreakPropertyParser`. Use `sbp` prefix on private file-local helpers.
- **`UnicodeProperties.SentenceBreak` enum** with **15 cases** (14 explicit UCD values + `other` default).
- **`SentenceBreakCode.rawValue(for:)`** mapping strings to UInt8.
- **`Array<SentenceBreakPropertyEntry>.expandSentenceBreak()`** returning `[UInt8]`, default-filled `0` (Other).
- **Generated table** `SentenceBreakTable.swift` (`TwoStageTrie<UInt8>`).
- **Entry point** `UnicodeProperties.sentenceBreak(of: Unicode.Scalar) -> SentenceBreak`.
- Stdlib-only at runtime.

### Out of scope

- **UAX #29 sentence segmentation algorithm** — uses this property + break rules. Separate sub-project.

## Property values (per UCD 16.0)

14 distinct values present in the file (plus implicit `Other`):
- ATerm (4 entries)
- Close (183)
- CR (1)
- Extend (555)
- Format (15)
- LF (1)
- Lower (687)
- Numeric (79)
- OLetter (598)
- SContinue (22)
- Sep (3)
- Sp (9)
- STerm (84)
- Upper (657)

Plus `Other` (default) = 15 enum cases.

## Module Layout

```
Sources/UnicodeProperties/
├── SentenceBreak.swift                          # new: enum + entry point
├── UnicodeProperties.swift                      # add sentenceBreak(of:)
└── Generated/
    └── SentenceBreakTable.swift                 # new (codegen)

Sources/BedrockUcdGen/
└── SentenceBreakPropertyParser.swift            # new
```

```
Tests/UnicodePropertiesTests/
├── SentenceBreakTests.swift                     # new
└── ExhaustiveTests.swift                        # extend (controller does, post-merge)

Tests/BedrockUcdGenTests/
├── SentenceBreakPropertyParserTests.swift       # new
└── ExpandSentenceBreakTests.swift               # new
```

## Public API

```swift
extension UnicodeProperties {

    /// Sentence_Break property (UAX #29). Used by sentence-
    /// segmentation algorithms. Returns `.other` for codepoints not
    /// explicitly listed in `SentenceBreakProperty.txt`.
    public enum SentenceBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other        = 0    // XX (default)
        case cr           = 1    // CR
        case lf           = 2    // LF
        case sep          = 3    // Sep
        case extend       = 4    // Extend
        case format       = 5    // Format
        case sp           = 6    // Sp
        case lower        = 7    // Lower
        case upper        = 8    // Upper
        case oLetter      = 9    // OLetter
        case numeric      = 10   // Numeric
        case aTerm        = 11   // ATerm
        case sTerm        = 12   // STerm
        case sContinue    = 13   // SContinue
        case close        = 14   // Close
    }

    /// O(1) Sentence_Break lookup.
    @inlinable
    public static func sentenceBreak(of scalar: Unicode.Scalar) -> SentenceBreak {
        let raw = sentenceBreakTable.lookup(scalar.value)
        return SentenceBreak(rawValue: raw) ?? .other
    }
}
```

## Codegen

Mirror Layer 2.10 exactly. `SentenceBreakPropertyEntry(first, last, value)`, range-based parsing with `#`-comment stripping and `sbp`-prefixed file-local helpers. `SentenceBreakCode.rawValue(for:)` maps 14 string values to UInt8 0-14 (Other=0 default + 14 explicit). Expansion fills with default 0.

## Edge Cases

| Case | Handling |
|---|---|
| ASCII `"A"` | `.upper`. |
| ASCII `"a"` | `.lower`. |
| ASCII digit | `.numeric`. |
| CR (U+000D) | `.cr`. |
| LF (U+000A) | `.lf`. |
| Period `.` (U+002E) | `.aTerm`. |
| Question mark `?` (U+003F) | `.sTerm`. |
| Exclamation mark `!` (U+0021) | `.sTerm`. |
| Comma `,` (U+002C) | `.sContinue`. |
| Closing paren `)` | `.close`. |
| Space `" "` (U+0020) | `.sp`. |
| Codepoint absent from UCD | `.other`. |

## Testing

- `SentenceBreakPropertyParserTests.swift` — 8 tests (single + range + comments + 4 rejection cases).
- `ExpandSentenceBreakTests.swift` — 6 tests.
- `SentenceBreakTests.swift` — spot-checks covering all 15 enum cases.

## Expected output size

Estimate ~40-60 unique trie blocks (slightly larger than WordBreak because Upper/Lower span huge swaths of Unicode), ~35-55 KB generated source.

## Non-Functional Requirements

- Stdlib-only runtime.
- O(1) lookup, Sendable, constant-time.
- Reuses `TwoStageTrieBuilder`, `CodeEmitter`, `emitUInt8`.

# Grapheme Break Property Design (Layer 2.10)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1 (codegen pipeline)
**Date:** 2026-05-23
**Parallel batch:** runs alongside Layer 2.9 (BidiBrackets) in a separate git worktree.

## Purpose

Ship the `Grapheme_Cluster_Break` property per UAX #29. This is the per-codepoint property table that an eventual grapheme-cluster segmentation algorithm will consume to find user-perceived character boundaries.

## Scope

### In scope (v1)

- **Vendored `GraphemeBreakProperty-16.0.0.txt`** (already at `Sources/UnicodeProperties/UCD/GraphemeBreakProperty.txt`, ~96 KB / 1503 lines / ~1419 data entries).
- **`GraphemeBreakPropertyParser`** with `GraphemeBreakPropertyEntry { first, last, value }`. Range-or-codepoint format, same shape as `DerivedCorePropertyParser`.
- **`UnicodeProperties.GraphemeClusterBreak` enum** with 14 cases (13 explicit values from UCD + `other` default).
- **One generated table** `GraphemeClusterBreakTable.swift` (`TwoStageTrie<UInt8>`).
- **One entry point** `UnicodeProperties.graphemeClusterBreak(of:) -> GraphemeClusterBreak`.
- **Default for absent codepoints**: `.other` (XX) per the UCD `@missing` directive.
- Stdlib-only at runtime.

### Out of scope
- **UAX #29 grapheme cluster segmentation algorithm** — uses this property + extensive break rules. Separate sub-project.
- **Word break / Sentence break properties** (`WordBreakProperty.txt`, `SentenceBreakProperty.txt`) — same shape, separate sub-projects.
- **Indic_Conjunct_Break property** (UAX #29 extension) — separate decision.
- **emoji-data.txt properties** (Extended_Pictographic) — used by UAX #29 GB11 rule; separate.

## Format

```
# @missing: 0000..10FFFF; Other

0600..0605    ; Prepend # Cf   [6] ARABIC NUMBER SIGN..ARABIC NUMBER MARK ABOVE
06DD          ; Prepend # Cf       ARABIC END OF AYAH
0D4E          ; Prepend # Lo       MALAYALAM LETTER DOT REPH
000D          ; CR # Cc       <control-000D>
000A          ; LF # Cc       <control-000A>
```

Two semicolon-separated fields per line: codepoint range, property value. Trailing `#`-comment. Identical structural shape to `DerivedCoreProperties.txt`.

## Property values (per UCD 16.0)

13 distinct values present in the file:
- Control (26 entries)
- CR (1)
- LF (1)
- Extend (412)
- L (2 ranges)
- LV (399)
- LVT (399)
- Prepend (16)
- Regional_Indicator (1)
- SpacingMark (155)
- T (2)
- V (4)
- ZWJ (1)

Plus implicit `Other` for unlisted codepoints. **Total: 14 enum cases.**

## Module Layout

```
Sources/UnicodeProperties/
├── GraphemeClusterBreak.swift                   # new: enum + entry point
├── UnicodeProperties.swift                      # add graphemeClusterBreak(of:)
└── Generated/
    └── GraphemeClusterBreakTable.swift          # new (codegen)

Sources/BedrockUcdGen/
└── GraphemeBreakPropertyParser.swift            # new
```

```
Tests/UnicodePropertiesTests/
├── GraphemeClusterBreakTests.swift              # new
└── ExhaustiveTests.swift                        # extend (controller does, post-merge)

Tests/BedrockUcdGenTests/
├── GraphemeBreakPropertyParserTests.swift       # new
└── ExpandGraphemeClusterBreakTests.swift        # new
```

## Public API

```swift
extension UnicodeProperties {

    /// Grapheme_Cluster_Break property (UAX #29). Used by grapheme-
    /// cluster segmentation. Returns `.other` for codepoints not
    /// explicitly listed in `GraphemeBreakProperty.txt` (UCD default).
    public enum GraphemeClusterBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other              = 0   // XX (default)
        case cr                 = 1   // CR
        case lf                 = 2   // LF
        case control            = 3   // Control
        case extend             = 4   // Extend
        case zwj                = 5   // ZWJ
        case regionalIndicator  = 6   // Regional_Indicator
        case prepend            = 7   // Prepend
        case spacingMark        = 8   // SpacingMark
        case l                  = 9   // L (Hangul lead)
        case v                  = 10  // V (Hangul vowel)
        case t                  = 11  // T (Hangul trailing)
        case lv                 = 12  // LV (Hangul lead-vowel)
        case lvt                = 13  // LVT (Hangul lead-vowel-trailing)
    }

    /// O(1) Grapheme_Cluster_Break lookup.
    @inlinable
    public static func graphemeClusterBreak(of scalar: Unicode.Scalar) -> GraphemeClusterBreak {
        let raw = graphemeClusterBreakTable.lookup(scalar.value)
        return GraphemeClusterBreak(rawValue: raw) ?? .other
    }
}
```

Storage: `TwoStageTrie<UInt8>` with values 0–13. Codepoints absent from UCD default to `0` (`.other`) — the initial fill.

## Codegen Changes

### `GraphemeBreakPropertyEntry` + parser

```swift
public struct GraphemeBreakPropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "CR", "LF", "Control", "Extend", "ZWJ",
                                // "Regional_Indicator", "Prepend",
                                // "SpacingMark", "L", "V", "T", "LV", "LVT"
}

public enum GraphemeBreakPropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum GraphemeBreakPropertyParser {
    public static func parse(_ text: String) throws -> [GraphemeBreakPropertyEntry]
}
```

Per-line: strip `#`-comment, trim, skip blank, split on `;`, require ≥ 2 fields. Field 0 supports `..` range. Reused private file-local trim + `range(of: "..")` helpers (or a stdlib-only `gbRange` analogue, prefixed to avoid cross-file collision).

### `GraphemeClusterBreakCode`

```swift
public enum GraphemeClusterBreakCode {
    /// Map UCD GCB value to UInt8 raw value matching
    /// UnicodeProperties.GraphemeClusterBreak.
    public static func rawValue(for value: String) throws -> UInt8 {
        switch value {
        case "Other":              return 0
        case "CR":                 return 1
        case "LF":                 return 2
        case "Control":            return 3
        case "Extend":             return 4
        case "ZWJ":                return 5
        case "Regional_Indicator": return 6
        case "Prepend":            return 7
        case "SpacingMark":        return 8
        case "L":                  return 9
        case "V":                  return 10
        case "T":                  return 11
        case "LV":                 return 12
        case "LVT":                return 13
        default:
            throw GraphemeBreakPropertyParseError.invalidCodepoint(lineNumber: -1, raw: value)
        }
    }
}
```

### Expansion helper

```swift
public extension Array where Element == GraphemeBreakPropertyEntry {
    func expandGraphemeClusterBreak() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)   // default Other (0)
        for entry in self {
            let value = try GraphemeClusterBreakCode.rawValue(for: entry.value)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}
```

### `main.swift` extension

Append after the East Asian Width emission (or any consistent location):
- Read `GraphemeBreakProperty.txt`, parse, expand, emit via `emitUInt8`.

## Edge Cases

| Case | Handling |
|---|---|
| ASCII `"A"` | `.other` (not listed). |
| ASCII `"5"` | `.other`. |
| CR (U+000D) | `.cr`. |
| LF (U+000A) | `.lf`. |
| Tab (U+0009) | `.control`. |
| NUL (U+0000) | `.control`. |
| Combining acute (U+0301) | `.extend`. |
| ZWJ (U+200D) | `.zwj`. |
| Regional Indicator Symbol A (U+1F1E6) | `.regionalIndicator`. |
| Hangul ㄱ (U+1100) | `.l`. |
| Hangul 가 (U+AC00) | `.lv`. |
| Hangul 각 (U+AC01) | `.lvt`. |
| Codepoint absent from UCD | `.other`. |

## Testing Strategy

### `GraphemeBreakPropertyParserTests.swift`
- Parses single-codepoint entry.
- Parses range entry.
- Ignores `#`-comments + blank lines + section headers.
- Returns multiple entries.
- Rejects invalid range, non-hex codepoint, empty value, truncated line.

### `ExpandGraphemeClusterBreakTests.swift`
- Empty entries → all-`.other` (0).
- Single CR entry sets one codepoint.
- Range Extend entry fills inclusive range.
- Unknown value throws.

### `GraphemeClusterBreakTests.swift`
- All 14 enum cases reachable via spot-checks (CR, LF, Control, Extend, ZWJ, RI, Prepend, SpacingMark, L, V, T, LV, LVT, Other).
- `allCases.count == 14`.

### Extended `ExhaustiveTests.swift` (controller does, post-merge)
- Add a line with range-check `rawValue <= 13`.

## Expected output size

13 distinct values + Other default. Block dedup should be very effective for the property — most codepoints (e.g., the bulk of CJK) are Other. Hangul ranges are large but uniform-valued. Estimate ~30–50 unique blocks → ~25–40 KB generated source.

## Non-Functional Requirements

- Stdlib-only runtime.
- O(1) lookup, Sendable.
- Reuses existing `TwoStageTrieBuilder`, `CodeEmitter`, `emitUInt8` infrastructure.

## Open Questions

None. All resolved during design:
- Property values: all 13 UCD values + Other default = 14 enum cases.
- Storage: same `TwoStageTrie<UInt8>` shape as XID/EAW/etc.
- Default `.other` via initial fill (raw 0).
- Parser shape: mirror `DerivedCorePropertyParser` (same UCD format family).

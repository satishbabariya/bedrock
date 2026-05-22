# East Asian Width Design (Layer 2.8)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1 (codegen pipeline, `TwoStageTrie`)
**Date:** 2026-05-22
**Parallel batch:** runs alongside Layer 2.7 (More DCP) in a separate git worktree.

## Purpose

Ship East Asian Width per UAX #11. Used by terminal layout (each codepoint occupies 1 or 2 visual columns), wrapping algorithms, and CJK-aware text rendering.

## Scope

### In scope
- **Vendored `EastAsianWidth-16.0.0.txt`** (already at `Sources/UnicodeProperties/UCD/EastAsianWidth.txt`, ~194 KB / 2686 lines).
- **New parser** `EastAsianWidthParser`: range-or-codepoint format identical in shape to `DerivedCorePropertyParser` (just one property per file instead of many).
- **New enum** `UnicodeProperties.EastAsianWidth` with 6 cases (`narrow`, `wide`, `halfwidth`, `fullwidth`, `ambiguous`, `neutral`).
- **New expansion helper** producing `[UInt8]` (raw values 0–5).
- **New generated table** `EastAsianWidthTable.swift` (`TwoStageTrie<UInt8>`).
- **New entry point** `UnicodeProperties.eastAsianWidth(of:) -> EastAsianWidth`.
- **Default for absent codepoints**: `.neutral` (raw 5), per the UCD file header.
- Stdlib-only at runtime.

### Out of scope
- **`isWide(_:)` convenience helper** combining `.wide + .fullwidth`. Easy to add later if needed.
- **East Asian Width-aware string-width computation** (`displayWidth(of: String)`). Higher-layer concern.

## Format (per UCD file header)

```
0000..001F;N     # Cc  [32] <control-0000>..<control-001F>
0020;Na          # Zs       SPACE
0021..0023;Na    # Po   [3] EXCLAMATION MARK..NUMBER SIGN
3000;F           # Zs       IDEOGRAPHIC SPACE
3001..3003;W     # Po   [3] IDEOGRAPHIC COMMA..DITTO MARK
```

Field 0: codepoint or `XXXX..YYYY` range. Field 1: property code (`A`/`F`/`H`/`N`/`Na`/`W`). Trailing `#`-comment ignored.

**Entry counts** (Unicode 16.0): A=198, F=34, H=17, N=2095, Na=42, W=257. Total 2643. **Default for absent codepoints: N (Neutral).**

## Module Layout

```
Sources/UnicodeProperties/
├── EastAsianWidth.swift                          # new: enum + entry point
├── UnicodeProperties.swift                       # add eastAsianWidth(of:)
└── Generated/
    └── EastAsianWidthTable.swift                 # new (codegen)

Sources/BedrockUcdGen/
└── EastAsianWidthParser.swift                    # new
```

```
Tests/UnicodePropertiesTests/
├── EastAsianWidthTests.swift                     # new
└── ExhaustiveTests.swift                         # extend

Tests/BedrockUcdGenTests/
├── EastAsianWidthParserTests.swift               # new
└── ExpandEastAsianWidthTests.swift               # new
```

## Public API

```swift
extension UnicodeProperties {

    /// East Asian Width property (UAX #11). Used by terminal layout
    /// and CJK-aware string-width computation. Returns `.neutral` for
    /// codepoints not present in `EastAsianWidth.txt` (the documented
    /// default).
    public enum EastAsianWidth: UInt8, Sendable, Hashable, CaseIterable {
        case narrow      = 0   // Na
        case wide        = 1   // W
        case halfwidth   = 2   // H
        case fullwidth   = 3   // F
        case ambiguous   = 4   // A
        case neutral     = 5   // N (default)
    }

    /// O(1) East Asian Width lookup.
    @inlinable
    public static func eastAsianWidth(of scalar: Unicode.Scalar) -> EastAsianWidth {
        let raw = eastAsianWidthTable.lookup(scalar.value)
        return EastAsianWidth(rawValue: raw) ?? .neutral
    }
}
```

Storage: `TwoStageTrie<UInt8>` with values 0–5. Codepoints absent from the UCD default to `5` (`.neutral`) — that's the table's initial fill.

## Codegen

### `EastAsianWidthEntry` + `EastAsianWidthParser`

```swift
public struct EastAsianWidthEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "A", "F", "H", "N", "Na", "W"
}

public enum EastAsianWidthParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum EastAsianWidthParser {
    public static func parse(_ text: String) throws -> [EastAsianWidthEntry]
}
```

Per-line: strip `#`-comment, trim, skip blank, split on `;`, two fields required. Field 0 may be a `..` range. Reused private trim helper (file-local).

### `EastAsianWidthCode`

```swift
public enum EastAsianWidthCode {
    /// Map UCD EAW code to UInt8 raw value matching UnicodeProperties.EastAsianWidth.
    public static func rawValue(for code: String) throws -> UInt8 {
        switch code {
        case "Na": return 0
        case "W":  return 1
        case "H":  return 2
        case "F":  return 3
        case "A":  return 4
        case "N":  return 5
        default: throw EastAsianWidthParseError.invalidCodepoint(lineNumber: -1, raw: code)
        }
    }
}
```

### Expansion helper

```swift
public extension Array where Element == EastAsianWidthEntry {
    func expandEastAsianWidth() throws -> [UInt8] {
        var out = [UInt8](repeating: 5, count: 0x110000)   // default: N (neutral)
        for entry in self {
            let value = try EastAsianWidthCode.rawValue(for: entry.value)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}
```

### `main.swift` extension

After the existing emission sections, parse `EastAsianWidth.txt` and emit one new table via the existing `emitUInt8` helper.

## Testing

### `EastAsianWidthTests.swift` — spot-checks
- ASCII `"A"` → `.narrow` (Na).
- ASCII `"5"` → `.narrow`.
- ASCII space → `.narrow`.
- Control character (U+0000) → `.neutral` (N).
- Fullwidth digit `"０"` (U+FF10) → `.fullwidth`.
- Halfwidth katakana ｱ (U+FF71) → `.halfwidth`.
- Wide CJK `"漢"` (U+6F22) → `.wide`.
- Wide ideographic space (U+3000) → `.fullwidth`.
- Greek `"Α"` (U+0391) → `.ambiguous`.
- Codepoint absent from UCD (e.g., U+E000 PUA) → `.ambiguous` (PUA is in the A range per UCD).

### `EastAsianWidthParserTests.swift`
- Parses range entries, single-codepoint entries, all 6 status codes.
- Rejects malformed inputs.

### `ExpandEastAsianWidthTests.swift`
- Empty entries → all-`.neutral` (5).
- Single entry fills correctly.
- Range entry fills inclusive.

### `ExhaustiveTests.swift`
- Add `_ = UnicodeProperties.eastAsianWidth(of: scalar)`. Range-check raw value 0–5.

## Edge Cases

| Case | Handling |
|---|---|
| ASCII | All Na (Narrow). |
| Control characters | Listed in UCD as N (Neutral). |
| PUA | Listed in UCD as A (Ambiguous). |
| Codepoint absent from UCD | Default N (Neutral) via initial fill. |
| Surrogates | Listed in UCD as N. |
| CJK ideographs | W. |

## Expected output size

Single table; tighter dedup than XID (only 6 possible values, vs identifier-valid is much sparser). Estimate ~20–30 unique blocks → ~30–40 KB Swift source.

## Non-Functional Requirements

- Stdlib-only runtime.
- O(1) lookup, Sendable.
- Reuses existing infrastructure (`TwoStageTrieBuilder`, `CodeEmitter`).

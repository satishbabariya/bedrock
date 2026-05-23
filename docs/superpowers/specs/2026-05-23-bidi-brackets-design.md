# Bidi Brackets Design (Layer 2.9)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1 (codegen pipeline)
**Date:** 2026-05-23
**Parallel batch:** runs alongside Layer 2.10 (GraphemeBreakProperty) in a separate git worktree.

## Purpose

Ship `Bidi_Paired_Bracket` and `Bidi_Paired_Bracket_Type` per UAX #9. Each bracket codepoint maps to its mirrored partner (e.g., `(` ↔ `)`) plus a type indicator (Open / Close / None). Used by the UAX #9 bidi algorithm to handle paired brackets correctly (e.g., `[abc]` in an RTL context).

## Scope

### In scope (v1)

- **Vendored `BidiBrackets-16.0.0.txt`** (already at `Sources/UnicodeProperties/UCD/BidiBrackets.txt`, ~9 KB / 193 lines / 128 entries: 64 Open + 64 Close pairs).
- **`BidiBracketsParser`** with `BidiBracketEntry { codepoint, pairedCodepoint, type }`.
- **`UnicodeProperties.BidiBracketType` enum** with 3 cases: `none = 0` (default), `open = 1` (`o`), `close = 2` (`c`).
- **Two parallel tables**:
  - **Type table** (`TwoStageTrie<UInt8>`): values 0/1/2; default 0 (none).
  - **Paired-codepoint table** (`TwoStageTrie<UInt32>`): the mirrored partner codepoint; default 0 = "no pair".
- **Two new entry points**:
  - `bidiBracketType(of: Unicode.Scalar) -> BidiBracketType`.
  - `pairedBracket(of: Unicode.Scalar) -> Unicode.Scalar?` returns `nil` for non-bracket codepoints.
- Stdlib-only at runtime.

### Out of scope
- **`Bidi_Mirrored` / `Bidi_Mirroring_Glyph`** — separate properties from `BidiMirroring.txt`. Useful for general mirror rendering but distinct from bracket pairing.
- **UAX #9 algorithm** itself — separate sub-project.

## Format

```
0028; 0029; o # LEFT PARENTHESIS
0029; 0028; c # RIGHT PARENTHESIS
005B; 005D; o # LEFT SQUARE BRACKET
005D; 005B; c # RIGHT SQUARE BRACKET
```

Three semicolon-separated fields: source codepoint, paired codepoint, type (`o` / `c`). Trailing `#`-comment. Only 128 lines total (64 pairs); no range form.

## Module Layout

```
Sources/UnicodeProperties/
├── BidiBrackets.swift                           # new: enum + 2 entry points
├── UnicodeProperties.swift                      # add bidiBracketType + pairedBracket
└── Generated/
    ├── BidiBracketTypeTable.swift               # new (codegen)
    └── BidiPairedBracketTable.swift             # new (codegen)

Sources/BedrockUcdGen/
└── BidiBracketsParser.swift                     # new
```

```
Tests/UnicodePropertiesTests/
├── BidiBracketsTests.swift                      # new
└── ExhaustiveTests.swift                        # extend (controller does, post-merge)

Tests/BedrockUcdGenTests/
├── BidiBracketsParserTests.swift                # new
└── ExpandBidiBracketsTests.swift                # new
```

## Public API

```swift
extension UnicodeProperties {

    /// Bidi paired bracket type (UAX #9, `Bidi_Paired_Bracket_Type`).
    /// Used by the UAX #9 bidi algorithm to handle paired brackets in
    /// mixed-directional text.
    public enum BidiBracketType: UInt8, Sendable, Hashable, CaseIterable {
        case none  = 0
        case open  = 1
        case close = 2
    }

    /// O(1) bracket-type lookup. Returns `.none` for codepoints that are
    /// not bracket characters.
    @inlinable
    public static func bidiBracketType(of scalar: Unicode.Scalar) -> BidiBracketType {
        let raw = bidiBracketTypeTable.lookup(scalar.value)
        return BidiBracketType(rawValue: raw) ?? .none
    }

    /// O(1) paired-bracket lookup. Returns the mirrored partner codepoint
    /// for bracket characters, `nil` for non-brackets.
    @inlinable
    public static func pairedBracket(of scalar: Unicode.Scalar) -> Unicode.Scalar? {
        let paired = bidiPairedBracketTable.lookup(scalar.value)
        return paired == 0 ? nil : Unicode.Scalar(paired)
    }
}
```

Storage convention:
- Type table: `0` = none (default), `1` = open, `2` = close.
- Paired table: `0` = no pair (default), nonzero = target codepoint.

## Codegen Changes

### `BidiBracketEntry` + `BidiBracketsParser`

```swift
public struct BidiBracketEntry: Equatable, Sendable {
    public let codepoint: UInt32
    public let pairedCodepoint: UInt32
    public let type: BidiBracketType   // "o"/"c"

    public enum BidiBracketType: Character, Sendable {
        case open  = "o"
        case close = "c"
    }
}

public enum BidiBracketsParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidType(lineNumber: Int, raw: String)
}

public enum BidiBracketsParser {
    public static func parse(_ text: String) throws -> [BidiBracketEntry]
}
```

Per-line: strip `#`-comment, trim, skip blank, split on `;`, require 3 fields. Field 0 = codepoint hex, field 1 = paired codepoint hex, field 2 = single character `o` or `c`. Reject anything else with structured errors.

### Expansion helpers

```swift
public extension Array where Element == BidiBracketEntry {
    /// Expand to type table: [UInt8] of length 0x110000, default 0,
    /// with 1 for Open and 2 for Close codepoints.
    func expandBidiBracketType() -> [UInt8]

    /// Expand to paired-codepoint table: [UInt32] of length 0x110000,
    /// default 0; nonzero = paired codepoint.
    func expandBidiPairedBracket() -> [UInt32]
}
```

### `main.swift` extension

Append after the existing East Asian Width emission:
- Read `BidiBrackets.txt`, parse into `[BidiBracketEntry]`.
- Emit type table via `emitUInt8` (existing helper).
- Emit paired table via `emitUInt32` (existing helper).

## Edge Cases

| Case | Handling |
|---|---|
| `(` (U+0028) | type = `.open`, paired = `)` (U+0029). |
| `)` (U+0029) | type = `.close`, paired = `(` (U+0028). |
| ASCII letter `"A"` | type = `.none`, paired = `nil`. |
| Codepoint absent from UCD | type = `.none`, paired = `nil`. Default 0 throughout. |
| `{`, `}`, `[`, `]` | All present as Open/Close pairs. |
| CJK brackets U+3008..U+3011 | Present in the file. |

## Testing Strategy

### `BidiBracketsParserTests.swift`
- Parses single Open entry (`0028; 0029; o`).
- Parses single Close entry (`0029; 0028; c`).
- Ignores comments + blank lines.
- Rejects invalid type character.
- Rejects non-hex codepoint.
- Rejects truncated lines.
- Realistic snippet with file header.

### `ExpandBidiBracketsTests.swift`
- Empty entries → both tables all-zero.
- Open entry: type[cp] = 1, paired[cp] = paired hex.
- Close entry: type[cp] = 2, paired[cp] = paired hex.
- Multiple entries: correct distinct indices.

### `BidiBracketsTests.swift`
- `bidiBracketType(of: "(") == .open`.
- `bidiBracketType(of: ")") == .close`.
- `bidiBracketType(of: "A") == .none`.
- `pairedBracket(of: "(") == ")"`.
- `pairedBracket(of: ")") == "("`.
- `pairedBracket(of: "A") == nil`.
- Square brackets and curly braces work.
- CJK brackets (e.g., U+3008 ↔ U+3009) work.
- `BidiBracketType.allCases.count == 3` (sanity).

### Extended `ExhaustiveTests.swift` (controller does, post-merge)
- Add 2 lines exercising both new entry points.

## Expected output sizes

Both tables are extremely sparse (128 active codepoints out of 1.1M). Block dedup will be aggressive — expect <10 unique blocks each, generated source ~5-15 KB per table. Total ~10-30 KB new generated source.

## Non-Functional Requirements

- Stdlib-only runtime.
- O(1) lookup, Sendable, constant-time.
- Reuses existing `TwoStageTrieBuilder`, `CodeEmitter`, `emitUInt8`, `emitUInt32` infrastructure.

## Open Questions

None. Storage shape and entry-point shapes mirror EastAsianWidth (type) + SimpleCaseMapping (paired codepoint).

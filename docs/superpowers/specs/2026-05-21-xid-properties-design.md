# XID Identifier Properties Design (Layer 2.5)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1–2.4 (`UnicodeProperties` library, `bedrock-ucd-gen`, generic `TwoStageTrie<Value>` infrastructure)
**Date:** 2026-05-21

## Purpose

Add UAX #31 identifier classification to `UnicodeProperties`: `isXIDStart(_:)` and `isXIDContinue(_:)`. These are the canonically-recommended properties for "is this codepoint a valid identifier start / continuation character", used by programming-language tooling, config parsers, URL/IDNA, JSON keys, and PRECIS.

This sub-project ingests a third UCD source file: `DerivedCoreProperties.txt`. The format is yet another shape — `range ; property # comment` per line, with many properties coexisting in one file. The parser is property-name-agnostic; the expansion helpers filter by name.

## Scope

### In scope (v1)

- **Vendored `DerivedCoreProperties-16.0.0.txt`** at `Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt`, ~1.1 MB / 13362 lines.
- **`DerivedCorePropertyEntry`** value type: `first: UInt32`, `last: UInt32`, `propertyName: String`.
- **`DerivedCorePropertyParser.parse(_:) throws -> [DerivedCorePropertyEntry]`** handling single-codepoint and range form (`XXXX..YYYY`). Skips `#`-comments and blank lines. Structured errors.
- Two expansion helpers: **`expandXIDStart()`** and **`expandXIDContinue()`**, each filtering entries by `propertyName` and writing 1 across the inclusive range.
- Two new generated `TwoStageTrie<UInt8>` tables: **`XIDStartTable.swift`**, **`XIDContinueTable.swift`**.
- Two new public entry points: **`isXIDStart(_: Unicode.Scalar) -> Bool`** and **`isXIDContinue(_: Unicode.Scalar) -> Bool`**.
- `main.swift` extension: parse `DerivedCoreProperties.txt` once, emit two tables (fourth and fifth emission steps after the existing CaseFolding step).
- Stdlib-only at runtime; Foundation in codegen.

### Out of scope (separate work)

- **`ID_Start` / `ID_Continue`** — legacy pre-XID properties present in the same file. Trivial follow-up (the parser already collects them; only the expansion helpers and entry points are missing).
- **Other DerivedCoreProperties entries** — `Math`, `Alphabetic`, `Cased`, `Case_Ignorable`, `Default_Ignorable_Code_Point`, `Grapheme_Extend` (will be foundational for UAX #29 segmentation), `Grapheme_Base`, `Lowercase`, `Uppercase`, `Indic_Conjunct_Break`. Each gets its own decision.
- **String-level `isValidIdentifier(_: String)`** — scalar iteration with start/continue logic. v1 stays scalar-level.
- **UAX #31 "Restricted_Identifier" / "Confusable" profiles** — built on top of `XID_*` but uses `IdentifierStatus.txt` / `IdentifierType.txt`. Separate.
- **PRECIS** (RFC 8264) — separate concern; uses `XID_*` as a building block.

## Module Layout (additions / modifications)

```
Sources/UnicodeProperties/
├── Identifier.swift                              # new: comment-only marker
├── UnicodeProperties.swift                       # add isXIDStart, isXIDContinue
├── Generated/
│   ├── ... existing seven tables ...
│   ├── XIDStartTable.swift                       # new (codegen)
│   └── XIDContinueTable.swift                    # new (codegen)
└── UCD/
    ├── UnicodeData.txt                           # existing
    ├── CaseFolding.txt                           # existing
    └── DerivedCoreProperties.txt                 # new (vendored 16.0.0)

Sources/BedrockUcdGen/
├── UCDParser.swift                               # unchanged
├── CaseFoldingParser.swift                       # unchanged
├── DerivedCorePropertyParser.swift               # new
├── TwoStageTrieBuilder.swift                     # unchanged (generic)
└── CodeEmitter.swift                             # unchanged (generic)

Sources/bedrock-ucd-gen/
└── main.swift                                    # add fourth + fifth emission steps
```

```
Tests/UnicodePropertiesTests/
└── IdentifierTests.swift                         # new (spot-checks)

Tests/BedrockUcdGenTests/
├── DerivedCorePropertyParserTests.swift          # new (parser tests)
└── ExpandXIDPropertiesTests.swift                # new (expansion-helper tests)
```

## Public API

```swift
extension UnicodeProperties {

    /// Whether `scalar` is a valid identifier-start character per UAX #31
    /// (the `XID_Start` derived property — recommended for new code).
    @inlinable
    public static func isXIDStart(_ scalar: Unicode.Scalar) -> Bool {
        xidStartTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is a valid identifier-continuation character per
    /// UAX #31 (the `XID_Continue` derived property).
    ///
    /// `XID_Start ⊂ XID_Continue` — every start codepoint is also a valid
    /// continuation.
    @inlinable
    public static func isXIDContinue(_ scalar: Unicode.Scalar) -> Bool {
        xidContinueTable.lookup(scalar.value) != 0
    }
}
```

Storage convention: `0` = not-in-property, `1` = in-property. Single `UInt8` per codepoint.

## Codegen Changes

### `DerivedCorePropertyEntry`

```swift
public struct DerivedCorePropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let propertyName: String

    public init(first: UInt32, last: UInt32, propertyName: String) {
        self.first = first
        self.last = last
        self.propertyName = propertyName
    }
}
```

### `DerivedCorePropertyParser`

```swift
public enum DerivedCorePropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyName(lineNumber: Int)
}

public enum DerivedCorePropertyParser {
    public static func parse(_ text: String) throws -> [DerivedCorePropertyEntry]
}
```

Per-line parsing:
1. Strip trailing `#`-comment.
2. Trim whitespace; skip blank lines.
3. Split by `;` (omittingEmptySubsequences: false); require ≥ 2 fields.
4. Field 0: codepoint or `XXXX..YYYY` range. If contains `..`, split and parse both halves; else single codepoint (first == last).
5. Field 1: trimmed property name. Required non-empty.
6. Return all entries (property-name-agnostic). Filtering happens in expansion helpers.

### Expansion helpers

```swift
public extension Array where Element == DerivedCorePropertyEntry {
    /// XID_Start: valid identifier-start codepoints.
    func expandXIDStart() -> [UInt8] {
        expand(matching: "XID_Start")
    }

    /// XID_Continue: valid identifier-continuation codepoints.
    func expandXIDContinue() -> [UInt8] {
        expand(matching: "XID_Continue")
    }

    /// Generic helper consumed by the property-specific entry points.
    private func expand(matching propertyName: String) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self where entry.propertyName == propertyName {
            for cp in entry.first...entry.last {
                out[Int(cp)] = 1
            }
        }
        return out
    }
}
```

### `main.swift` extension

After the existing three emission sections (uint8Outputs loop, uint32Outputs loop, CaseFolding step), append a single parse + two emission steps:

```swift
print("---")
print("Parsing DerivedCoreProperties.txt ...")
let dcpPath = "Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt"
let dcpText: String
do {
    dcpText = try String(contentsOfFile: dcpPath, encoding: .utf8)
} catch { print("Failed to read \(dcpPath): \(error)"); exit(1) }
let dcpEntries: [DerivedCorePropertyEntry]
do {
    dcpEntries = try DerivedCorePropertyParser.parse(dcpText)
    print("Parsed \(dcpEntries.count) DerivedCoreProperty entries.")
} catch { print("DerivedCoreProperties parse error: \(error)"); exit(1) }

print("---")
print("Processing: XID_Start")
emitUInt8("Sources/UnicodeProperties/Generated/XIDStartTable.swift",
           "xidStartTable", "XID_Start", dcpEntries.expandXIDStart())

print("---")
print("Processing: XID_Continue")
emitUInt8("Sources/UnicodeProperties/Generated/XIDContinueTable.swift",
           "xidContinueTable", "XID_Continue", dcpEntries.expandXIDContinue())
```

`emitUInt8` is the existing helper.

## Edge Cases

| Case | Handling |
|---|---|
| Single-codepoint entry (e.g., `005F ; XID_Continue`) | `first == last` — handled by the range-form path naturally. |
| Range entry (`0041..005A ; XID_Start`) | `..` detected; parsed as `[first, last]` inclusive. |
| ASCII digit `"0"` | XID_Continue only — NOT XID_Start. Crucial test case. |
| Underscore `"_"` (U+005F) | XID_Continue only — NOT XID_Start. Programming languages that allow `_foo` extend this spec. |
| Combining acute `\u{0301}` | XID_Continue only. Combining marks can extend but can't start. |
| ASCII space / control / punctuation | Neither. Return false. |
| CJK ideograph `"漢"` (U+6F22) | Both XID_Start and XID_Continue. |
| Codepoint absent from `DerivedCoreProperties.txt` | Default 0 → false. |
| Trailing `..` (e.g., `0041..` with no second codepoint) | `invalidRange` error. |
| Empty property name | `emptyPropertyName` error. |
| Section-header lines starting with `#` | Skipped after `#` strip + trim. |

### Block dedup expectations

Most codepoints are not identifier-valid (control, whitespace, format, symbols, etc.). Many 256-codepoint blocks will be all-zero. Aggressive dedup expected — estimate **20–40 unique blocks per property** → ~15–25 KB Swift source each, for a total of ~30–50 KB added.

## Testing Strategy

Each new test file targets ≥ 90% line coverage on its source.

### `UnicodePropertiesTests/IdentifierTests.swift`
- ASCII positives: `isXIDStart("A")`, `isXIDStart("z")`.
- ASCII negatives: `isXIDStart("0")` false, `isXIDStart("_")` false, `isXIDStart(" ")` false, `isXIDStart("!")` false.
- ASCII XID_Continue: `"A"`, `"0"`, `"_"` all true; `" "` false.
- Latin-1: `isXIDStart("\u{00C0}")` true (À); `isXIDStart("\u{00B7}")` false but `isXIDContinue("\u{00B7}")` true (middle dot).
- CJK: `isXIDStart("\u{6F22}")` true; `isXIDContinue("\u{6F22}")` true.
- Combining marks: `isXIDStart(Unicode.Scalar(0x0301)!)` false; `isXIDContinue(Unicode.Scalar(0x0301)!)` true.
- Greek: `isXIDStart(Unicode.Scalar(0x03A3)!)` true; `isXIDStart(Unicode.Scalar(0x03C2)!)` true.
- PUA / format: `isXIDStart(Unicode.Scalar(0xE000)!)` false; `isXIDStart(Unicode.Scalar(0x200B)!)` false.
- **Containment property**: for a representative sample of codepoints, `isXIDStart(x)` implies `isXIDContinue(x)`.

### `BedrockUcdGenTests/DerivedCorePropertyParserTests.swift`
- Parses a single-codepoint entry.
- Parses a range entry.
- Ignores `#`-comments and blank lines.
- Trims whitespace correctly.
- Returns multiple entries for the same range under different property names.
- Rejects invalid range format.
- Rejects non-hex codepoint.
- Rejects empty property name.
- Handles a realistic snippet with section-header comments.

### `BedrockUcdGenTests/ExpandXIDPropertiesTests.swift`
- Empty entries → all-zero arrays.
- Single XID_Start entry sets one codepoint to 1.
- Range XID_Start entry sets inclusive range; bordering codepoints stay 0.
- Entry with a different property name skipped by `expandXIDStart`.
- Mixed entries: each helper picks up only its own.

### Extended `ExhaustiveTests.swift`
- Add `_ = UnicodeProperties.isXIDStart(scalar)` and `_ = UnicodeProperties.isXIDContinue(scalar)` to the existing per-codepoint loop.

## Non-Functional Requirements

- **Stdlib only** at runtime. Foundation only in `bedrock-ucd-gen`.
- **O(1) lookup** for both new entry points.
- **Sendable** end-to-end.
- **Expected generated source**: ~15–25 KB per property table, ~30–50 KB total.
- **Expected parsed entries**: ~14K total in `DerivedCoreProperties.txt`; XID_Start ~766, XID_Continue ~1397 (per UCD 16.0).

## Open Questions

None. All resolved during brainstorming:
- Properties bundled: XID_Start + XID_Continue (legacy ID_* deferred).
- Storage: same `TwoStageTrie<UInt8>` shape, 0 = false / 1 = true.
- Parser: property-name-agnostic; expansion helpers filter.
- main.swift integration: parse once, emit twice (fourth and fifth emission steps overall).
- Vendored file source: <https://www.unicode.org/Public/16.0.0/ucd/DerivedCoreProperties.txt>.

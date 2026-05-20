# Simple Case Folding Design (Layer 2.4)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1–2.3 (`UnicodeProperties` library, `bedrock-ucd-gen`, generic `TwoStageTrie<UInt32>` infrastructure)
**Date:** 2026-05-20

## Purpose

Add scalar-level **simple case folding** (single-codepoint output) to `UnicodeProperties`. Folding is the *correct* operation for case-insensitive comparison — uppercase/lowercase mappings are not folding-equivalent for several codepoints (most notably Greek final sigma `ς` and capital sigma `Σ`, which both fold to `σ`).

This sub-project also extends the codegen pipeline to consume a **second UCD file**: `CaseFolding.txt`. Prior sub-projects all read from `UnicodeData.txt`. The new `CaseFoldingParser` parses a different (simpler) UCD format with `;`-separated fields and `#`-comments.

## Scope

### In scope (v1)

- **Vendored `CaseFolding-16.0.0.txt`** at `Sources/UnicodeProperties/UCD/CaseFolding.txt`, ~84 KB / 1654 lines.
- **`CaseFoldingEntry`** value type: `codepoint: UInt32`, `status: Status` (enum `C`/`F`/`S`/`T`), `mapping: [UInt32]`.
- **`CaseFoldingParser.parse(_:)`** producing `[CaseFoldingEntry]`. Skips `#`-comments and blank lines. Trims field whitespace. Rejects malformed inputs with structured errors.
- **`expandSimpleCaseFolding()`** extension on `[CaseFoldingEntry]` returning a 0x110000-element `[UInt32]`. Consumes only single-codepoint mappings with status `C` or `S`. Skips `F` (multi-codepoint output, deferred) and `T` (locale-dependent, deferred). When both `C` and `S` exist for the same codepoint (not present in UCD 16.0 but defensively handled), `S` wins.
- **`SimpleCaseFoldingTable.swift`** generated file. `TwoStageTrie<UInt32>`; storage convention `0` = identity.
- **`UnicodeProperties.caseFolded(of:) -> Unicode.Scalar`** O(1) entry point.
- `main.swift` extension: a third emission step alongside the existing `uint8Outputs` and `uint32Outputs` loops, since this property's source file is different.
- Stdlib-only at runtime; Foundation in codegen as before.

### Out of scope (separate work)

- **Full case folding** (multi-codepoint output, status `F` — e.g., `ß → ss`, `İ → i̇`). Variable-length output requires a different storage shape (flat scalar array + offset/length table). Own sub-project.
- **Turkic-only folding** (status `T`) — Turkish/Azerbaijani locale-dependent rules. Own sub-project.
- **Status-aware lookup API** exposing `C`/`S`/`F`/`T` separately. Implementation detail.
- **String-level `caseFolded(_: String) -> String`**. Needs scalar iteration; v1 stays scalar-level.
- **`caseInsensitiveCompare(_:_:)`** built on folding. Separate concern.

## Module Layout (additions / modifications)

```
Sources/UnicodeProperties/
├── CaseFolding.swift                             # new: comment-only marker
├── UnicodeProperties.swift                       # add caseFolded(of:) entry point
├── Generated/
│   ├── ... existing six tables ...
│   └── SimpleCaseFoldingTable.swift              # new (codegen)
└── UCD/
    ├── UnicodeData.txt                           # existing
    └── CaseFolding.txt                           # new (vendored 16.0.0)

Sources/BedrockUcdGen/
├── UCDParser.swift                               # unchanged
├── CaseFoldingParser.swift                       # new
├── TwoStageTrieBuilder.swift                     # unchanged (already generic)
└── CodeEmitter.swift                             # unchanged (already generic)

Sources/bedrock-ucd-gen/
└── main.swift                                    # add third emission step
```

```
Tests/UnicodePropertiesTests/
└── CaseFoldingTests.swift                        # new (spot-checks)

Tests/BedrockUcdGenTests/
├── CaseFoldingParserTests.swift                  # new (parser tests)
└── ExpandSimpleCaseFoldingTests.swift            # new (expansion-helper tests)
```

## Public API

```swift
extension UnicodeProperties {

    /// Simple case folding (CaseFolding.txt statuses C + S — single-
    /// codepoint folding only). Returns the input scalar unchanged when
    /// no folding applies.
    ///
    /// For case-insensitive comparison, folding is the correct operation
    /// (not lowercasing). Folding maps disparate cased forms (e.g., Greek
    /// "Σ" and "ς") to a single canonical form ("σ") for comparison.
    ///
    /// Multi-codepoint folding (e.g., "ß" → "ss") requires status `F`;
    /// that's a separate sub-project. Turkic-locale folding (status `T`)
    /// is locale-dependent and also deferred.
    @inlinable
    public static func caseFolded(of scalar: Unicode.Scalar) -> Unicode.Scalar
}
```

Storage convention identical to case mapping: `0` = identity; any nonzero value is the target codepoint.

```swift
let raw = simpleCaseFoldingTable.lookup(scalar.value)
return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
```

## Codegen Changes

### `CaseFoldingEntry`

```swift
public struct CaseFoldingEntry: Equatable, Sendable {
    public enum Status: Character, Sendable {
        case common  = "C"
        case full    = "F"
        case simple  = "S"
        case turkic  = "T"
    }

    public let codepoint: UInt32
    public let status: Status
    public let mapping: [UInt32]   // 1 element for C/S/T, ≥1 for F
}
```

### `CaseFoldingParser`

```swift
public enum CaseFoldingParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidStatus(lineNumber: Int, raw: String)
    case emptyMapping(lineNumber: Int)
}

public enum CaseFoldingParser {
    public static func parse(_ text: String) throws -> [CaseFoldingEntry]
}
```

Parsing flow per line:
1. Strip trailing `#`-comment.
2. Strip leading/trailing whitespace.
3. Skip blank lines.
4. Split by `;` (omittingEmptySubsequences: false).
5. Require ≥ 3 fields.
6. Field 0 = codepoint hex (parse via `UInt32(_, radix: 16)`).
7. Field 1 = single-character status (`C`/`F`/`S`/`T`); reject otherwise.
8. Field 2 = space-separated hex codepoints (must be non-empty after trimming).

### Expansion helper

```swift
public extension Array where Element == CaseFoldingEntry {
    /// Expand to a 0x110000-element uncompacted [UInt32] containing the
    /// simple case-folded target codepoint (0 = identity).
    ///
    /// Honors statuses C and S only (single-codepoint mappings).
    /// If both exist for the same codepoint, S takes priority
    /// (Unicode-documented). F and T entries are skipped.
    func expandSimpleCaseFolding() -> [UInt32]
}
```

Implementation: two-pass write (first C, then S overrides). Filters to `mapping.count == 1` defensively.

### `main.swift` extension

The existing `main.swift` has two loops:
- `uint8Outputs` (general category, bidi class, CCC — all from `UnicodeData.txt`).
- `uint32Outputs` (three simple-case-mapping tables — all from `UnicodeData.txt`).

Add a **third emission step after both loops**, separately because the source file is different:

```
1. Read CaseFolding.txt
2. Parse to [CaseFoldingEntry]
3. expandSimpleCaseFolding() -> [UInt32]
4. emitUInt32(...SimpleCaseFoldingTable.swift, "simpleCaseFoldingTable", "simple case folding", ...)
```

The existing `emitUInt32` helper is reused unchanged.

## Edge Cases

| Case | Handling |
|---|---|
| ASCII `"A"` | C entry → folds to `"a"`. |
| ASCII `"a"` | No entry → identity. |
| ASCII non-letters (`"5"`, `" "`, etc.) | No entry → identity. |
| Latin-1 `"À"` (U+00C0) | C entry → folds to `"à"`. |
| Greek capital sigma `"Σ"` (U+03A3) | C entry → folds to `"σ"`. |
| Greek final sigma `"ς"` (U+03C2) | C entry → folds to `"σ"` (**folding equivalence with `Σ`**; this is the canonical headline result). |
| German sharp s `"ß"` (U+00DF) | Only F entry — no simple folding. Identity in v1. |
| Turkish dotted I `"İ"` (U+0130) | F and T entries — no simple folding. Identity in v1. |
| Titlecase letter `"ǅ"` (U+01C5) | C entry → folds to `"ǆ"` (U+01C6). |
| CJK / Hangul / Tangut ranges | No entries. Identity. |
| `C` + `S` collision on same codepoint | Not present in UCD 16.0.0 (verified). Two-pass design defensively handles it — `S` wins. |
| Multi-codepoint `C` mapping | Not present in well-formed UCD. Defensively filtered (`mapping.count == 1`) before writing. |

## Testing Strategy

Each new test file targets ≥ 90% line coverage on its corresponding source file.

### `UnicodePropertiesTests/CaseFoldingTests.swift` — spot-checks
- ASCII pairs: `"A"`→`"a"`, ..., `"Z"`→`"z"`.
- ASCII identity: `"a"`→`"a"`, `"5"`→`"5"`, `" "`→`" "`, `"!"`→`"!"`.
- Latin-1: `"À"`→`"à"`.
- Greek headline: `"Σ"`→`"σ"`, `"ς"`→`"σ"`, `"σ"`→`"σ"`.
- ß identity, İ identity, CJK identity.
- Titlecase letter U+01C5 → U+01C6.
- Folding-equivalence assertion: `caseFolded("A") == caseFolded("a")`; `caseFolded("Σ") == caseFolded("ς")`.

### `BedrockUcdGenTests/CaseFoldingParserTests.swift`
- Parses a C entry.
- Parses an F entry with multi-codepoint mapping.
- Parses an S entry.
- Parses a T entry.
- Ignores `#`-comments and blank lines.
- Trims whitespace correctly.
- Rejects invalid status character.
- Rejects non-hex codepoint.
- Rejects an empty mapping field.
- Handles a realistic UCD-style snippet with file-header comments.

### `BedrockUcdGenTests/ExpandSimpleCaseFoldingTests.swift`
- Empty entries → all-zero array.
- Single C entry fills one codepoint.
- Single S entry fills one codepoint.
- F and T entries are ignored.
- A multi-codepoint mapping marked `C` (synthetic; shouldn't occur in UCD) is defensively skipped.
- Both C and S entries for the same codepoint (synthetic): S wins.

### Extended `ExhaustiveTests.swift`
- Add `_ = UnicodeProperties.caseFolded(of: scalar)` to the existing per-codepoint loop. Soft assertion: no trap.

## Non-Functional Requirements

- **Stdlib only** at runtime. Foundation only in `bedrock-ucd-gen`.
- **O(1) lookup** for `caseFolded(of:)`.
- **Sendable** end-to-end.
- **Expected output size**: ~25–45 KB Swift source. Block dedup should be very effective (most codepoints have no folding); estimate 15–30 unique blocks.
- **Expected entry counts** for Unicode 16.0:
  - 1453 C entries (used in simple folding).
  - 31 S entries (used in simple folding).
  - 104 F entries (skipped in v1).
  - 2 T entries (skipped in v1).
  - **Total usable for simple folding: 1484 entries.**

## Open Questions

None. All resolved during brainstorming:
- Statuses included: C + S (with S override). F and T deferred.
- Parser format: standard UCD line format with `#`-comments and `;`-separated fields.
- Storage: same `TwoStageTrie<UInt32>` shape as case mapping; 0 = identity.
- main.swift integration: third emission step, separate from existing two loops (different source file).
- Vendored file source: <https://www.unicode.org/Public/16.0.0/ucd/CaseFolding.txt>.

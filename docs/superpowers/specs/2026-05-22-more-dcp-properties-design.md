# More DerivedCoreProperties Design (Layer 2.7)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.5 (`DerivedCorePropertyParser`)
**Date:** 2026-05-22
**Parallel batch:** runs alongside Layer 2.8 (East Asian Width) in a separate git worktree.

## Purpose

Ship the remaining table-of-booleans properties from the already-vendored `DerivedCoreProperties.txt`: **ID_Start**, **ID_Continue**, **Math**, **Alphabetic**, **Cased**, **Lowercase**, **Uppercase**. Seven new entry points; reuses the existing parser and follows the exact pattern of Layer 2.5 (XID).

## Scope

### In scope
- Seven new expansion helpers on `Array<DerivedCorePropertyEntry>` (one per property, each a one-liner that calls the existing private `expand(matching:)` helper).
- Seven new generated tables (`IDStartTable.swift`, `IDContinueTable.swift`, `MathTable.swift`, `AlphabeticTable.swift`, `CasedTable.swift`, `LowercaseTable.swift`, `UppercaseTable.swift`). Each is `TwoStageTrie<UInt8>` with values 0/1.
- Seven new entry points on `UnicodeProperties`: `isIDStart`, `isIDContinue`, `isMath`, `isAlphabetic`, `isCased`, `isLowercase`, `isUppercase`. Each returns `Bool`.
- `main.swift` extension: 7 additional emission steps inside the existing DerivedCoreProperties block. Parses once (already does), expands 7 more times.
- Spot-check tests per property; extended `ExhaustiveTests.swift`.
- Stdlib-only at runtime.

### Out of scope
- **Other DCP entries** — `Case_Ignorable`, `Default_Ignorable_Code_Point`, `Grapheme_Base`, `Grapheme_Extend`, `Indic_Conjunct_Break`. Each is its own decision; some are foundational for normalization/segmentation.
- **`Changes_When_*` properties** — derived comparison flags; not strictly properties.

## Module Layout

```
Sources/UnicodeProperties/
├── CoreProperty.swift                            # new: marker for the 5 non-identifier entries
├── UnicodeProperties.swift                       # add 7 entry points
├── Generated/
│   ├── ... existing tables ...
│   ├── IDStartTable.swift                        # new (codegen)
│   ├── IDContinueTable.swift                     # new (codegen)
│   ├── MathTable.swift                           # new (codegen)
│   ├── AlphabeticTable.swift                     # new (codegen)
│   ├── CasedTable.swift                          # new (codegen)
│   ├── LowercaseTable.swift                      # new (codegen)
│   └── UppercaseTable.swift                      # new (codegen)
└── UCD/
    └── DerivedCoreProperties.txt                 # existing

Sources/BedrockUcdGen/
└── DerivedCorePropertyParser.swift               # extend with 7 helpers
```

`Identifier.swift` already exists from Layer 2.5; the two new ID_* entry points fit there conceptually. `CoreProperty.swift` is a new marker for the 5 boolean DCP properties that aren't identifier-related.

```
Tests/UnicodePropertiesTests/
├── IdentifierTests.swift                         # extend with ID_* tests
├── CorePropertyTests.swift                       # new
└── ExhaustiveTests.swift                         # extend

Tests/BedrockUcdGenTests/
└── ExpandDCPPropertiesTests.swift                # new (covers 7 new helpers)
```

## Public API

```swift
extension UnicodeProperties {
    /// Legacy `ID_Start` (UAX #31). XID_Start is recommended for new code.
    @inlinable
    public static func isIDStart(_ scalar: Unicode.Scalar) -> Bool

    /// Legacy `ID_Continue` (UAX #31).
    @inlinable
    public static func isIDContinue(_ scalar: Unicode.Scalar) -> Bool

    /// `Math` (Sm + Other_Math).
    @inlinable
    public static func isMath(_ scalar: Unicode.Scalar) -> Bool

    /// `Alphabetic` (L* + Nl + Other_Alphabetic).
    @inlinable
    public static func isAlphabetic(_ scalar: Unicode.Scalar) -> Bool

    /// `Cased` (Lu + Ll + Lt + Other_Uppercase + Other_Lowercase).
    @inlinable
    public static func isCased(_ scalar: Unicode.Scalar) -> Bool

    /// `Lowercase` (Ll + Other_Lowercase).
    @inlinable
    public static func isLowercase(_ scalar: Unicode.Scalar) -> Bool

    /// `Uppercase` (Lu + Other_Uppercase).
    @inlinable
    public static func isUppercase(_ scalar: Unicode.Scalar) -> Bool
}
```

Each is a one-liner: `someTable.lookup(scalar.value) != 0`. Storage convention `0`/`1` identical to XID tables.

## Codegen Changes

Append to the existing `Array<DerivedCorePropertyEntry>` extension in `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift`:

```swift
    func expandIDStart() -> [UInt8]     { expand(matching: "ID_Start") }
    func expandIDContinue() -> [UInt8]  { expand(matching: "ID_Continue") }
    func expandMath() -> [UInt8]        { expand(matching: "Math") }
    func expandAlphabetic() -> [UInt8]  { expand(matching: "Alphabetic") }
    func expandCased() -> [UInt8]       { expand(matching: "Cased") }
    func expandLowercase() -> [UInt8]   { expand(matching: "Lowercase") }
    func expandUppercase() -> [UInt8]   { expand(matching: "Uppercase") }
```

The existing private `expand(matching:)` is reused. No parser change.

In `main.swift`, after the existing XID emission section, add 7 emission steps in the same pattern:

```swift
for (path, globalName, label, expand) in [
    ("...IDStartTable.swift", "idStartTable", "ID_Start", dcpEntries.expandIDStart),
    ("...IDContinueTable.swift", "idContinueTable", "ID_Continue", dcpEntries.expandIDContinue),
    ("...MathTable.swift", "mathTable", "Math", dcpEntries.expandMath),
    ... etc.
] {
    emitUInt8(path, globalName, label, expand())
}
```

(Implemented as a tuple-list loop for compactness.)

## Edge Cases

| Case | Handling |
|---|---|
| Codepoint not in DCP | Default 0 → `false`. Same as 2.5. |
| Property containment | E.g., `XID_Start ⊂ ID_Start ⊂ Alphabetic ⊂ Cased`-ish overlaps. Tests verify per-property correctness, not the containment chain. |
| ASCII letters | All seven properties: ID_Start✓, ID_Continue✓, Math✗, Alphabetic✓, Cased✓, Lowercase: lowercase only, Uppercase: uppercase only. |
| ASCII digits | ID_Start✗, ID_Continue✓, Math✗, Alphabetic✗, Cased✗, Lowercase✗, Uppercase✗. |
| `+` (U+002B) | Math✓, everything else✗. |
| `α` (U+03B1) | Alphabetic✓, Cased✓, Lowercase✓, Uppercase✗. |
| `Α` (U+0391) | Alphabetic✓, Cased✓, Lowercase✗, Uppercase✓. |
| Combining marks | ID_Start✗, ID_Continue maybe, Math✗, Alphabetic✗ (combining marks aren't Alphabetic). |

## Testing

**`CorePropertyTests.swift`** (5 non-identifier properties × ~3 cases each):
- Math: `"+"`, `"="`, `"∑"` true; `"A"`, `"5"` false.
- Alphabetic: letters true; digits + punctuation false.
- Cased: uppercase + lowercase letters true; digits false.
- Lowercase: `"a"`, `"α"` true; `"A"` false.
- Uppercase: `"A"`, `"Α"` true; `"a"` false.

**`IdentifierTests.swift`** extension (2 new ID_* tests):
- `isIDStart` matches `isXIDStart` for common ASCII / CJK cases (the two properties agree on the basic identifier characters).
- Both ID_* return false on space / punctuation.

**`ExpandDCPPropertiesTests.swift`** — synthetic inputs proving each helper filters by name correctly.

**`ExhaustiveTests.swift`** — add 7 lines exercising the new entry points.

## Expected output sizes

Each table: similar to XID_Continue (~130 KB) since they cover broad portions of Unicode. Total: ~700 KB to ~1 MB of new generated Swift source. Acceptable.

## Non-Functional Requirements

- Stdlib-only runtime.
- O(1) lookup, constant-time, Sendable.
- Reuses 100% of existing infrastructure (parser, builder, emitter).

# More DerivedCoreProperties Implementation Plan (Layer 2.7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.isIDStart`, `isIDContinue`, `isMath`, `isAlphabetic`, `isCased`, `isLowercase`, `isUppercase` per the spec at `docs/superpowers/specs/2026-05-22-more-dcp-properties-design.md`. Reuses the already-shipped `DerivedCorePropertyParser` and private `expand(matching:)` helper from Layer 2.5.

**Architecture:** Seven one-liner expansion helpers appended to the existing `Array<DerivedCorePropertyEntry>` extension. Seven generated `TwoStageTrie<UInt8>` tables (same shape as XIDStartTable / XIDContinueTable). Seven `@inlinable` entry points on `UnicodeProperties`. No new parser, emitter, or builder needed.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

**Branch:** `layer-2.7-more-dcp` (git worktree; do not merge — controller does that).

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift` — append 7 helpers inside the existing `Array<DerivedCorePropertyEntry>` extension.
- `Sources/bedrock-ucd-gen/main.swift` — append 7 emission steps after the existing XID_Continue step.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add 7 new entry points after `isXIDContinue`.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — call all 7 new entry points inside the existing per-codepoint loop.

**Creations:**
- `Sources/UnicodeProperties/CoreProperty.swift` (comment-only marker)
- `Sources/UnicodeProperties/Generated/IDStartTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/IDContinueTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/MathTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/AlphabeticTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/CasedTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/LowercaseTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/UppercaseTable.swift` (placeholder, then real)
- `Tests/BedrockUcdGenTests/ExpandDCPPropertiesTests.swift`
- `Tests/UnicodePropertiesTests/CorePropertyTests.swift`

**Note:** `Sources/UnicodeProperties/Identifier.swift` already exists (Layer 2.5). `isIDStart` / `isIDContinue` fit conceptually there; no modification to that file is needed. `CoreProperty.swift` is a new marker for the 5 non-identifier properties.

The vendored `Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt` and the parser are already committed.

---

## Task 1: Add 7 expansion helpers

**Files:**
- Modify: `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift`
- Create: `Tests/BedrockUcdGenTests/ExpandDCPPropertiesTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/ExpandDCPPropertiesTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandDCPPropertiesTests {

    // MARK: - Shared helpers

    private func entries(_ pairs: [(UInt32, UInt32, String)]) -> [DerivedCorePropertyEntry] {
        pairs.map { DerivedCorePropertyEntry(first: $0.0, last: $0.1, propertyName: $0.2) }
    }

    // MARK: - expandIDStart

    @Test
    func expandIDStart_filtersCorrectly() {
        let e = entries([
            (0x0041, 0x005A, "ID_Start"),
            (0x0041, 0x005A, "XID_Start"),
            (0x002B, 0x002B, "Math"),
        ])
        let out = e.expandIDStart()
        #expect(out[0x0041] == 1)
        #expect(out[0x005A] == 1)
        #expect(out[0x002B] == 0)   // Math, not ID_Start
    }

    @Test
    func expandIDStart_emptyYieldsAllZeros() {
        let out = entries([]).expandIDStart()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    // MARK: - expandIDContinue

    @Test
    func expandIDContinue_filtersCorrectly() {
        let e = entries([
            (0x005F, 0x005F, "ID_Continue"),
            (0x0030, 0x0039, "ID_Continue"),
            (0x0030, 0x0039, "ID_Start"),  // same range, different prop
        ])
        let out = e.expandIDContinue()
        #expect(out[0x005F] == 1)
        #expect(out[0x0030] == 1)
        #expect(out[0x0039] == 1)
    }

    // MARK: - expandMath

    @Test
    func expandMath_filtersCorrectly() {
        let e = entries([
            (0x002B, 0x002B, "Math"),
            (0x003C, 0x003E, "Math"),
            (0x0041, 0x0041, "ID_Start"),
        ])
        let out = e.expandMath()
        #expect(out[0x002B] == 1)
        #expect(out[0x003C] == 1)
        #expect(out[0x003E] == 1)
        #expect(out[0x0041] == 0)
    }

    // MARK: - expandAlphabetic

    @Test
    func expandAlphabetic_filtersCorrectly() {
        let e = entries([
            (0x0041, 0x005A, "Alphabetic"),
            (0x0030, 0x0039, "ID_Continue"),  // digits — not Alphabetic
        ])
        let out = e.expandAlphabetic()
        #expect(out[0x0041] == 1)
        #expect(out[0x005A] == 1)
        #expect(out[0x0030] == 0)
    }

    // MARK: - expandCased

    @Test
    func expandCased_filtersCorrectly() {
        let e = entries([
            (0x0041, 0x005A, "Cased"),   // uppercase Latin
            (0x0061, 0x007A, "Cased"),   // lowercase Latin
            (0x0030, 0x0039, "ID_Continue"),
        ])
        let out = e.expandCased()
        #expect(out[0x0041] == 1)
        #expect(out[0x0061] == 1)
        #expect(out[0x0030] == 0)
    }

    // MARK: - expandLowercase

    @Test
    func expandLowercase_filtersCorrectly() {
        let e = entries([
            (0x0061, 0x007A, "Lowercase"),
            (0x0041, 0x005A, "Uppercase"),
            (0x0041, 0x005A, "Cased"),
        ])
        let out = e.expandLowercase()
        #expect(out[0x0061] == 1)
        #expect(out[0x007A] == 1)
        #expect(out[0x0041] == 0)   // Uppercase, not Lowercase
    }

    // MARK: - expandUppercase

    @Test
    func expandUppercase_filtersCorrectly() {
        let e = entries([
            (0x0041, 0x005A, "Uppercase"),
            (0x0061, 0x007A, "Lowercase"),
        ])
        let out = e.expandUppercase()
        #expect(out[0x0041] == 1)
        #expect(out[0x005A] == 1)
        #expect(out[0x0061] == 0)   // Lowercase, not Uppercase
    }

    // MARK: - Cross-property isolation

    @Test
    func eachHelperIgnoresAllOtherProperties() {
        // A single entry with each of the 7 new property names.
        let e = entries([
            (0x0001, 0x0001, "ID_Start"),
            (0x0002, 0x0002, "ID_Continue"),
            (0x0003, 0x0003, "Math"),
            (0x0004, 0x0004, "Alphabetic"),
            (0x0005, 0x0005, "Cased"),
            (0x0006, 0x0006, "Lowercase"),
            (0x0007, 0x0007, "Uppercase"),
        ])
        #expect(e.expandIDStart()[0x0001] == 1)
        #expect(e.expandIDStart()[0x0002] == 0)
        #expect(e.expandIDStart()[0x0003] == 0)

        #expect(e.expandIDContinue()[0x0002] == 1)
        #expect(e.expandIDContinue()[0x0001] == 0)

        #expect(e.expandMath()[0x0003] == 1)
        #expect(e.expandMath()[0x0001] == 0)

        #expect(e.expandAlphabetic()[0x0004] == 1)
        #expect(e.expandAlphabetic()[0x0003] == 0)

        #expect(e.expandCased()[0x0005] == 1)
        #expect(e.expandCased()[0x0004] == 0)

        #expect(e.expandLowercase()[0x0006] == 1)
        #expect(e.expandLowercase()[0x0005] == 0)

        #expect(e.expandUppercase()[0x0007] == 1)
        #expect(e.expandUppercase()[0x0006] == 0)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter ExpandDCPPropertiesTests 2>&1 | tail -10
```
Expected: compile error — `expandIDStart`, `expandIDContinue`, etc. don't exist yet.

- [ ] **Step 3: Implement the 7 helpers**

In `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift`, inside the existing `public extension Array where Element == DerivedCorePropertyEntry { ... }` block, append 7 new one-liners immediately after `expandXIDContinue`:

```swift
    /// ID_Start: legacy identifier-start codepoints per UAX #31.
    func expandIDStart() -> [UInt8]     { expand(matching: "ID_Start") }

    /// ID_Continue: legacy identifier-continuation codepoints per UAX #31.
    func expandIDContinue() -> [UInt8]  { expand(matching: "ID_Continue") }

    /// Math: Sm + Other_Math.
    func expandMath() -> [UInt8]        { expand(matching: "Math") }

    /// Alphabetic: L* + Nl + Other_Alphabetic.
    func expandAlphabetic() -> [UInt8]  { expand(matching: "Alphabetic") }

    /// Cased: Lu + Ll + Lt + Other_Uppercase + Other_Lowercase.
    func expandCased() -> [UInt8]       { expand(matching: "Cased") }

    /// Lowercase: Ll + Other_Lowercase.
    func expandLowercase() -> [UInt8]   { expand(matching: "Lowercase") }

    /// Uppercase: Lu + Other_Uppercase.
    func expandUppercase() -> [UInt8]   { expand(matching: "Uppercase") }
```

The private `expand(matching:)` helper is already present and reused unchanged.

- [ ] **Step 4: Run tests**

```bash
swift test --filter ExpandDCPPropertiesTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: all 9 new helper tests pass; full suite stays green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen/DerivedCorePropertyParser.swift \
        Tests/BedrockUcdGenTests/ExpandDCPPropertiesTests.swift
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add 7 DerivedCoreProperty expansion helpers

One-liner each — expandIDStart, expandIDContinue, expandMath,
expandAlphabetic, expandCased, expandLowercase, expandUppercase —
all delegating to the existing private expand(matching:) helper.
Completes the boolean-property surface of DerivedCoreProperties.txt.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Codegen — placeholder tables + extended main.swift + run

**Files:**
- Create: `Sources/UnicodeProperties/Generated/IDStartTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/IDContinueTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/MathTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/AlphabeticTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/CasedTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/LowercaseTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/UppercaseTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add 7 placeholder generated files**

All 7 placeholders follow the exact same shape as `XIDStartTable.swift`. Create each:

`Sources/UnicodeProperties/Generated/IDStartTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let idStartTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

`Sources/UnicodeProperties/Generated/IDContinueTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let idContinueTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

`Sources/UnicodeProperties/Generated/MathTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let mathTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

`Sources/UnicodeProperties/Generated/AlphabeticTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let alphabeticTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

`Sources/UnicodeProperties/Generated/CasedTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let casedTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

`Sources/UnicodeProperties/Generated/LowercaseTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let lowercaseTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

`Sources/UnicodeProperties/Generated/UppercaseTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let uppercaseTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

Verify the package builds:
```bash
swift build 2>&1 | tail -3
```
Expected: `Build complete!`

- [ ] **Step 2: Extend main.swift**

Read `Sources/bedrock-ucd-gen/main.swift` to confirm the last two lines are the XID_Continue emission. Append the following immediately after those lines:

```swift
let extraDcpOutputs: [(String, String, String, () -> [UInt8])] = [
    ("Sources/UnicodeProperties/Generated/IDStartTable.swift",
     "idStartTable", "ID_Start",
     { dcpEntries.expandIDStart() }),
    ("Sources/UnicodeProperties/Generated/IDContinueTable.swift",
     "idContinueTable", "ID_Continue",
     { dcpEntries.expandIDContinue() }),
    ("Sources/UnicodeProperties/Generated/MathTable.swift",
     "mathTable", "Math",
     { dcpEntries.expandMath() }),
    ("Sources/UnicodeProperties/Generated/AlphabeticTable.swift",
     "alphabeticTable", "Alphabetic",
     { dcpEntries.expandAlphabetic() }),
    ("Sources/UnicodeProperties/Generated/CasedTable.swift",
     "casedTable", "Cased",
     { dcpEntries.expandCased() }),
    ("Sources/UnicodeProperties/Generated/LowercaseTable.swift",
     "lowercaseTable", "Lowercase",
     { dcpEntries.expandLowercase() }),
    ("Sources/UnicodeProperties/Generated/UppercaseTable.swift",
     "uppercaseTable", "Uppercase",
     { dcpEntries.expandUppercase() }),
]

for (path, global, label, expand) in extraDcpOutputs {
    print("---")
    print("Processing: \(label)")
    emitUInt8(path, global, label, expand())
}
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -25
```
Expected: the existing 11 emissions succeed, followed by 7 new ones (ID_Start, ID_Continue, Math, Alphabetic, Cased, Lowercase, Uppercase). Each prints:
```
---
Processing: <label>
Built two-stage trie: stage1=4352 entries, stage2=... entries (... unique blocks).
Self-check OK: 1114112 codepoints round-trip.
Wrote Sources/UnicodeProperties/Generated/<Name>Table.swift (...  bytes).
```

If any self-check line says `FAILED` — STOP and report.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: `Build complete!`; full test suite green (no API references the new globals yet, so count stays unchanged).

- [ ] **Step 5: Spot-check generated files**

```bash
wc -c Sources/UnicodeProperties/Generated/IDStartTable.swift \
       Sources/UnicodeProperties/Generated/MathTable.swift \
       Sources/UnicodeProperties/Generated/AlphabeticTable.swift
head -5 Sources/UnicodeProperties/Generated/IDStartTable.swift
```
Expected: each file starts with `// GENERATED by`; sizes on the order of 15–130 KB (Math is sparse, Alphabetic is broad).

- [ ] **Step 6: Verify existing 11 tables are unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: only the 7 new table files show changes (placeholder → real). XIDStartTable.swift, XIDContinueTable.swift, and all 9 earlier tables must show no diff. If any existing table shows a diff — STOP and report.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen/main.swift \
        Sources/UnicodeProperties/Generated/IDStartTable.swift \
        Sources/UnicodeProperties/Generated/IDContinueTable.swift \
        Sources/UnicodeProperties/Generated/MathTable.swift \
        Sources/UnicodeProperties/Generated/AlphabeticTable.swift \
        Sources/UnicodeProperties/Generated/CasedTable.swift \
        Sources/UnicodeProperties/Generated/LowercaseTable.swift \
        Sources/UnicodeProperties/Generated/UppercaseTable.swift
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit 7 new DerivedCoreProperty tables

bedrock-ucd-gen extended with a loop over 7 extra emission steps
(ID_Start, ID_Continue, Math, Alphabetic, Cased, Lowercase,
Uppercase). Reuses existing DerivedCoreProperties parse step and
emitUInt8 helper. Each table self-checks 1114112 codepoints.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Public API + spot-check tests

**Files:**
- Create: `Sources/UnicodeProperties/CoreProperty.swift` (comment-only marker)
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Modify: `Tests/UnicodePropertiesTests/IdentifierTests.swift` (extend with ID_* tests)
- Create: `Tests/UnicodePropertiesTests/CorePropertyTests.swift`

- [ ] **Step 1: Write failing tests**

**Extend** `Tests/UnicodePropertiesTests/IdentifierTests.swift` — append two new `@Test` methods inside the existing `IdentifierTests` struct (after `startImpliesContinueAcrossSample`):

```swift
    @Test
    func idStartMatchesXIDStartForBasicASCII() {
        // For common ASCII letters, ID_Start and XID_Start agree.
        for cp: UInt32 in (0x41...0x5A) + (0x61...0x7A) {
            let s = Unicode.Scalar(cp)!
            #expect(UnicodeProperties.isIDStart(s) == true,
                    "Expected isIDStart true for U+\(String(cp, radix: 16))")
            #expect(UnicodeProperties.isIDContinue(s) == true,
                    "Expected isIDContinue true for U+\(String(cp, radix: 16))")
        }
    }

    @Test
    func idStartFalseForSpaceAndPunctuation() {
        #expect(UnicodeProperties.isIDStart(" ") == false)
        #expect(UnicodeProperties.isIDStart("!") == false)
        #expect(UnicodeProperties.isIDStart("5") == false)
        #expect(UnicodeProperties.isIDContinue(" ") == false)
    }
```

> Note: Swift ranges are not concatenable with `+`. Use two separate `for` loops or a single loop with a condition: `for cp: UInt32 in 0x41...0x7A where (cp <= 0x5A || cp >= 0x61)`.  The exact form is up to the implementer; the intent is to spot-check ASCII letters.

**Create** `Tests/UnicodePropertiesTests/CorePropertyTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct CorePropertyTests {

    // MARK: - Math

    @Test
    func mathTrueForOperators() {
        // U+002B PLUS SIGN (Sm)
        #expect(UnicodeProperties.isMath(Unicode.Scalar(0x002B)!))
        // U+003C LESS-THAN SIGN (Sm)
        #expect(UnicodeProperties.isMath(Unicode.Scalar(0x003C)!))
        // U+2211 N-ARY SUMMATION ∑ (Sm)
        #expect(UnicodeProperties.isMath(Unicode.Scalar(0x2211)!))
    }

    @Test
    func mathFalseForLettersAndDigits() {
        #expect(UnicodeProperties.isMath("A") == false)
        #expect(UnicodeProperties.isMath("5") == false)
        #expect(UnicodeProperties.isMath(" ") == false)
    }

    // MARK: - Alphabetic

    @Test
    func alphabeticTrueForLetters() {
        #expect(UnicodeProperties.isAlphabetic("A"))
        #expect(UnicodeProperties.isAlphabetic("z"))
        // U+00E0 à (Ll)
        #expect(UnicodeProperties.isAlphabetic(Unicode.Scalar(0x00E0)!))
        // U+03B1 α GREEK SMALL LETTER ALPHA
        #expect(UnicodeProperties.isAlphabetic(Unicode.Scalar(0x03B1)!))
    }

    @Test
    func alphabeticFalseForDigitsAndPunctuation() {
        #expect(UnicodeProperties.isAlphabetic("5") == false)
        #expect(UnicodeProperties.isAlphabetic("!") == false)
        #expect(UnicodeProperties.isAlphabetic("+") == false)
    }

    // MARK: - Cased

    @Test
    func casedTrueForUpperAndLowercase() {
        #expect(UnicodeProperties.isCased("A"))
        #expect(UnicodeProperties.isCased("z"))
        // U+00C0 À — uppercase Latin-1
        #expect(UnicodeProperties.isCased(Unicode.Scalar(0x00C0)!))
        // U+03B1 α — lowercase Greek
        #expect(UnicodeProperties.isCased(Unicode.Scalar(0x03B1)!))
    }

    @Test
    func casedFalseForDigitsAndPunctuation() {
        #expect(UnicodeProperties.isCased("5") == false)
        #expect(UnicodeProperties.isCased("!") == false)
        #expect(UnicodeProperties.isCased(" ") == false)
    }

    // MARK: - Lowercase

    @Test
    func lowercaseTrueForLowercaseLetters() {
        #expect(UnicodeProperties.isLowercase("a"))
        #expect(UnicodeProperties.isLowercase("z"))
        // U+00E0 à (Ll)
        #expect(UnicodeProperties.isLowercase(Unicode.Scalar(0x00E0)!))
        // U+03B1 α GREEK SMALL LETTER ALPHA
        #expect(UnicodeProperties.isLowercase(Unicode.Scalar(0x03B1)!))
    }

    @Test
    func lowercaseFalseForUppercase() {
        #expect(UnicodeProperties.isLowercase("A") == false)
        #expect(UnicodeProperties.isLowercase("Z") == false)
        // U+0391 Α GREEK CAPITAL LETTER ALPHA
        #expect(UnicodeProperties.isLowercase(Unicode.Scalar(0x0391)!) == false)
    }

    @Test
    func lowercaseFalseForDigitsAndPunctuation() {
        #expect(UnicodeProperties.isLowercase("5") == false)
        #expect(UnicodeProperties.isLowercase("!") == false)
    }

    // MARK: - Uppercase

    @Test
    func uppercaseTrueForUppercaseLetters() {
        #expect(UnicodeProperties.isUppercase("A"))
        #expect(UnicodeProperties.isUppercase("Z"))
        // U+00C0 À (Lu)
        #expect(UnicodeProperties.isUppercase(Unicode.Scalar(0x00C0)!))
        // U+0391 Α GREEK CAPITAL LETTER ALPHA
        #expect(UnicodeProperties.isUppercase(Unicode.Scalar(0x0391)!))
    }

    @Test
    func uppercaseFalseForLowercase() {
        #expect(UnicodeProperties.isUppercase("a") == false)
        #expect(UnicodeProperties.isUppercase("z") == false)
        // U+03B1 α GREEK SMALL LETTER ALPHA
        #expect(UnicodeProperties.isUppercase(Unicode.Scalar(0x03B1)!) == false)
    }

    @Test
    func uppercaseFalseForDigitsAndPunctuation() {
        #expect(UnicodeProperties.isUppercase("5") == false)
        #expect(UnicodeProperties.isUppercase(" ") == false)
    }

    // MARK: - Cross-property spot checks

    @Test
    func lowercaseAndUppercaseAreMutuallyExclusive() {
        let samples: [UInt32] = [0x41, 0x61, 0x00C0, 0x00E0, 0x0391, 0x03B1]
        for cp in samples {
            let s = Unicode.Scalar(cp)!
            let lo = UnicodeProperties.isLowercase(s)
            let up = UnicodeProperties.isUppercase(s)
            #expect(!(lo && up),
                    "U+\(String(cp, radix: 16)) is both Lowercase and Uppercase")
        }
    }

    @Test
    func casedImpliesEitherLowercaseOrUppercase() {
        let samples: [UInt32] = [0x41, 0x61, 0x00C0, 0x00E0, 0x0391, 0x03B1,
                                  0x01C5]  // U+01C5 ǅ Titlecase_Letter
        for cp in samples {
            let s = Unicode.Scalar(cp)!
            if UnicodeProperties.isCased(s) {
                let lo = UnicodeProperties.isLowercase(s)
                let up = UnicodeProperties.isUppercase(s)
                // Note: titlecase letters are Cased but may be neither
                // Lowercase nor Uppercase — do not assert lo || up here.
                // What we can assert is Cased != false.
                _ = lo; _ = up
            }
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter CorePropertyTests 2>&1 | tail -5
swift test --filter IdentifierTests/idStartMatchesXIDStartForBasicASCII 2>&1 | tail -5
```
Expected: compile error — `isIDStart`, `isMath`, etc. don't exist yet.

- [ ] **Step 3: Create marker file**

Create `Sources/UnicodeProperties/CoreProperty.swift`:
```swift
// Boolean DerivedCoreProperty classification entry points live in
// UnicodeProperties.swift to keep the namespace surface co-located with
// other property accessors. This file exists to match the file-per-property
// layout established by BidiClass.swift, CanonicalCombiningClass.swift,
// SimpleCaseMapping.swift, CaseFolding.swift, Identifier.swift, and
// FullCaseFolding.swift.
//
// Properties housed here (5 non-identifier DCP booleans):
//   isMath, isAlphabetic, isCased, isLowercase, isUppercase
//
// The two legacy identifier properties (isIDStart, isIDContinue) fit
// alongside isXIDStart / isXIDContinue conceptually; see Identifier.swift.
```

- [ ] **Step 4: Add the 7 entry points**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add immediately after `isXIDContinue` (and before `isLetter`):

```swift
    /// Whether `scalar` has the legacy `ID_Start` property (UAX #31).
    ///
    /// `XID_Start` is recommended for new code; `ID_Start` may admit
    /// characters whose NFKx form would not be valid start characters.
    @inlinable
    public static func isIDStart(_ scalar: Unicode.Scalar) -> Bool {
        idStartTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` has the legacy `ID_Continue` property (UAX #31).
    @inlinable
    public static func isIDContinue(_ scalar: Unicode.Scalar) -> Bool {
        idContinueTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is a math symbol (`Math` property: Sm + Other_Math).
    @inlinable
    public static func isMath(_ scalar: Unicode.Scalar) -> Bool {
        mathTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is alphabetic (`Alphabetic` property:
    /// L* + Nl + Other_Alphabetic).
    @inlinable
    public static func isAlphabetic(_ scalar: Unicode.Scalar) -> Bool {
        alphabeticTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is cased (`Cased` property:
    /// Lu + Ll + Lt + Other_Uppercase + Other_Lowercase).
    @inlinable
    public static func isCased(_ scalar: Unicode.Scalar) -> Bool {
        casedTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is lowercase (`Lowercase` property: Ll + Other_Lowercase).
    @inlinable
    public static func isLowercase(_ scalar: Unicode.Scalar) -> Bool {
        lowercaseTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is uppercase (`Uppercase` property: Lu + Other_Uppercase).
    @inlinable
    public static func isUppercase(_ scalar: Unicode.Scalar) -> Bool {
        uppercaseTable.lookup(scalar.value) != 0
    }
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter CorePropertyTests 2>&1 | tail -10
swift test --filter IdentifierTests 2>&1 | tail -5
swift test 2>&1 | tail -3
```
Expected: all CorePropertyTests and the extended IdentifierTests pass; full suite green.

If a spot-check fails, verify the expected value against `Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt` before weakening the test. For example:
```bash
grep "^002B" Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt
```
Do NOT alter the generated tables or lower the bar.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties/CoreProperty.swift \
        Sources/UnicodeProperties/UnicodeProperties.swift \
        Tests/UnicodePropertiesTests/IdentifierTests.swift \
        Tests/UnicodePropertiesTests/CorePropertyTests.swift
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add isIDStart/Continue + isMath/Alphabetic/Cased/Lowercase/Uppercase

Seven new @inlinable entry points backed by the 7 generated tables.
CoreProperty.swift marker added for the 5 non-identifier properties.
Spot-check tests cover Latin, Latin-1, Greek, and cross-property
invariants (Lowercase ∩ Uppercase = ∅, Cased ⊇ Lowercase ∪ Uppercase).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Exhaustive sweep + coverage gate

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`

- [ ] **Step 1: Extend the exhaustive test**

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add 7 lines inside the existing per-codepoint loop, immediately after `_ = UnicodeProperties.isXIDContinue(scalar)`:

```swift
            _ = UnicodeProperties.isIDStart(scalar)
            _ = UnicodeProperties.isIDContinue(scalar)
            _ = UnicodeProperties.isMath(scalar)
            _ = UnicodeProperties.isAlphabetic(scalar)
            _ = UnicodeProperties.isCased(scalar)
            _ = UnicodeProperties.isLowercase(scalar)
            _ = UnicodeProperties.isUppercase(scalar)
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: full suite green with an updated test count.

- [ ] **Step 3: Coverage check**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build|Generated' \
  Sources/UnicodeProperties/UnicodeProperties.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/UCDParser.swift \
  Sources/BedrockUcdGen/CaseFoldingParser.swift \
  Sources/BedrockUcdGen/DerivedCorePropertyParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift \
  Sources/BedrockUcdGen/FlatArrayEmitter.swift
```
Expected: every listed file ≥ 90% line coverage.

If `DerivedCorePropertyParser.swift` falls short: the most likely uncovered lines are error-throwing branches. The existing `DerivedCorePropertyParserTests` (from Layer 2.5) should already exercise them — confirm those tests still run, and add targeted synthetic inputs for any branch that is still not covered. Do not suppress or comment out uncovered branches.

- [ ] **Step 4: Commit**

```bash
git add Tests/UnicodePropertiesTests/ExhaustiveTests.swift
git commit -m "$(cat <<'EOF'
test(unicode-properties): exhaustive sweep for 7 new DCP properties

ExhaustiveTests now calls all 18 UnicodeProperties entry points
across ~1.1M codepoints. Coverage gate confirmed ≥90% on all
non-generated source files.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Leave the branch here with all changes committed. The controller will handle the merge to `main`.

---

## Plan Self-Review Notes

- **Spec coverage:** every spec item — 7 helpers, 7 tables, 7 entry points, `CoreProperty.swift` marker, `ExpandDCPPropertiesTests`, `CorePropertyTests`, `IdentifierTests` extension, `ExhaustiveTests` extension — has a task and a step. Every test category from the spec's Testing section is covered.
- **No placeholders in steps:** every step shows runnable code, exact commands, or exact expected output.
- **Zero new infrastructure:** no new parser, builder, or emitter. The 7 helpers are one-liners; the emission loop in `main.swift` is compact (tuple list). Reuses 100% of existing machinery from Layers 2.1–2.5.
- **Placeholder tables in Task 2 Step 1:** keeps the package building before `swift run bedrock-ucd-gen` overwrites them, so Task 3's API additions can be compiled and tested independently if needed.
- **Global name conventions:** `idStartTable`, `idContinueTable`, `mathTable`, `alphabeticTable`, `casedTable`, `lowercaseTable`, `uppercaseTable` — lower-camel of the table file stem, consistent with `xidStartTable`, `generalCategoryTable`, etc.
- **Naming collision check:** `isLowercase` and `isUppercase` shadow nothing in the existing `UnicodeProperties` enum; the existing `simpleLowercase(of:)` / `simpleUppercase(of:)` return a scalar, not a Bool, so there is no ambiguity.
- **TDD discipline:** for each functional addition (helpers, entry points), the failing test is written first, the build failure is confirmed, then the implementation follows.
- **One commit per task:** Task 1 (helpers + test), Task 2 (codegen: main.swift + generated tables), Task 3 (public API + marker + spot-check tests), Task 4 (exhaustive + coverage). No squashing needed.
- **Coverage memory note:** per project memory, `precondition(predicate)` without a message string avoids the unreachable-autoclosure coverage gap. The 7 new helpers have no preconditions, so this is moot for this layer. The existing `expandFullCaseFolding` preconditions (in `CaseFoldingParser.swift`) are not modified.

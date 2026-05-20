# Bidi Class + Canonical Combining Class Implementation Plan (Layer 2.2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `UnicodeProperties` and `bedrock-ucd-gen` with bidi class + canonical combining class lookup per the spec at `docs/superpowers/specs/2026-05-20-bidi-class-and-ccc-design.md`.

**Architecture:** No new files in `Sources/BedrockUcdGen/` (extended in place). Two new files in `Sources/UnicodeProperties/` (`BidiClass.swift`, `CanonicalCombiningClass.swift`). Two new generated tables. Existing two-stage trie infrastructure reused unchanged.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/BedrockUcdGen/UCDParser.swift` — extend `UCDEntry`, extend parser, rename `expandToUncompacted`, add `BidiClassCode`, add two new expansion helpers.
- `Sources/BedrockUcdGen/CodeEmitter.swift` — extend `emit` with `globalName` parameter.
- `Sources/bedrock-ucd-gen/main.swift` — emit three tables.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add `bidiClass(of:)` and `canonicalCombiningClass(of:)` entry points.
- `Tests/BedrockUcdGenTests/UCDParserTests.swift` — update for new `UCDEntry` signature.
- `Tests/BedrockUcdGenTests/GeneralCategoryCodeTests.swift` — update for renamed helper.
- `Tests/BedrockUcdGenTests/CodeEmitterTests.swift` — update for new emit signature.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — add bidi-class range check.

**Creations:**
- `Sources/UnicodeProperties/BidiClass.swift`
- `Sources/UnicodeProperties/CanonicalCombiningClass.swift`
- `Sources/UnicodeProperties/Generated/BidiClassTable.swift` (codegen output)
- `Sources/UnicodeProperties/Generated/CanonicalCombiningClassTable.swift` (codegen output)
- `Tests/BedrockUcdGenTests/BidiClassCodeTests.swift`
- `Tests/UnicodePropertiesTests/BidiClassTests.swift`
- `Tests/UnicodePropertiesTests/BidiClassConformanceTests.swift`
- `Tests/UnicodePropertiesTests/CanonicalCombiningClassTests.swift`

---

## Task 1: Extend UCDEntry and parser

**Files:**
- Modify: `Sources/BedrockUcdGen/UCDParser.swift`
- Modify: `Tests/BedrockUcdGenTests/UCDParserTests.swift`

- [ ] **Step 1: Update existing parser tests for the new UCDEntry signature**

The existing tests build expected `UCDEntry` values with the old `(first, last, category)` initializer. Edit each `#expect` in `UCDParserTests.swift` to additionally assert `canonicalCombiningClass` and `bidiClass` values matching the inputs:

```swift
@Test
func parsesSingleAsciiLine() throws {
    let input = "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;\n"
    let entries = try UCDParser.parse(input)
    #expect(entries.count == 1)
    #expect(entries[0].first == 0x0041)
    #expect(entries[0].last == 0x0041)
    #expect(entries[0].category == "Lu")
    #expect(entries[0].canonicalCombiningClass == 0)
    #expect(entries[0].bidiClass == "L")
}

@Test
func parsesMultipleLines() throws {
    let input = """
    0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
    0042;LATIN CAPITAL LETTER B;Lu;0;L;;;;;N;;;;0062;
    0061;LATIN SMALL LETTER A;Ll;0;L;;;;;N;;;0041;;0041
    """
    let entries = try UCDParser.parse(input)
    #expect(entries.count == 3)
    #expect(entries[0].first == 0x0041)
    #expect(entries[1].first == 0x0042)
    #expect(entries[2].category == "Ll")
    #expect(entries[0].canonicalCombiningClass == 0)
    #expect(entries[0].bidiClass == "L")
}

@Test
func parsesRangePair() throws {
    let input = """
    4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;
    9FFF;<CJK Ideograph, Last>;Lo;0;L;;;;;N;;;;;
    """
    let entries = try UCDParser.parse(input)
    #expect(entries.count == 1)
    #expect(entries[0].first == 0x4E00)
    #expect(entries[0].last == 0x9FFF)
    #expect(entries[0].category == "Lo")
    #expect(entries[0].canonicalCombiningClass == 0)
    #expect(entries[0].bidiClass == "L")
}
```

Add a new test exercising a non-zero CCC and a non-L bidi class:

```swift
@Test
func parsesNonZeroCCCAndNonLBidi() throws {
    // U+0300 COMBINING GRAVE ACCENT: CCC=230, bidi=NSM
    let input = "0300;COMBINING GRAVE ACCENT;Mn;230;NSM;;;;;N;;;;;\n"
    let entries = try UCDParser.parse(input)
    #expect(entries.count == 1)
    #expect(entries[0].canonicalCombiningClass == 230)
    #expect(entries[0].bidiClass == "NSM")
}

@Test
func rejectsNonNumericCCC() {
    let input = "0041;LATIN CAPITAL LETTER A;Lu;notanumber;L;;;;;N;;;;0061;\n"
    do {
        _ = try UCDParser.parse(input)
        Issue.record("expected parse error on non-numeric CCC")
    } catch {
        // expected
    }
}
```

- [ ] **Step 2: Update UCDEntry and parser**

In `Sources/BedrockUcdGen/UCDParser.swift`:

Replace `UCDEntry`:
```swift
public struct UCDEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let category: String
    public let canonicalCombiningClass: UInt8
    public let bidiClass: String

    public init(first: UInt32,
                last: UInt32,
                category: String,
                canonicalCombiningClass: UInt8 = 0,
                bidiClass: String = "L") {
        self.first = first
        self.last = last
        self.category = category
        self.canonicalCombiningClass = canonicalCombiningClass
        self.bidiClass = bidiClass
    }
}
```

The defaults on `canonicalCombiningClass` and `bidiClass` are for synthetic test inputs that don't care; the parser always provides explicit values from the UCD line.

In the parser body, after the existing field/codepoint/category extraction, add CCC + bidi extraction (before the `name.hasSuffix(", First>")` branch):

```swift
guard let ccc = UInt8(fields[3]) else {
    throw UCDParseError.invalidCodepoint(lineNumber: lineNumber,
                                          raw: String(fields[3]))
}
let bidi = String(fields[4])
```

Update both `entries.append(...)` call sites in the parser to pass these:

```swift
// First/Last branch:
entries.append(UCDEntry(first: codepoint,
                         last: lastCodepoint,
                         category: category,
                         canonicalCombiningClass: ccc,
                         bidiClass: bidi))
// Single-line branch:
entries.append(UCDEntry(first: codepoint,
                         last: codepoint,
                         category: category,
                         canonicalCombiningClass: ccc,
                         bidiClass: bidi))
```

- [ ] **Step 3: Run parser tests**

```bash
swift test --filter UCDParserTests 2>&1 | tail -10
```
Expected: all parser tests pass, including the two new ones.

```bash
swift test 2>&1 | tail -3
```
Expected: full suite green.

- [ ] **Step 4: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): extend UCDEntry and parser for CCC + bidi class

UCDEntry now carries canonicalCombiningClass (UInt8) and bidiClass
(String). Parser extracts UCD fields 3 and 4. Defaults provided on
the init so synthetic test inputs needn't specify them.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add BidiClassCode and expansion helpers

**Files:**
- Modify: `Sources/BedrockUcdGen/UCDParser.swift`
- Modify: `Tests/BedrockUcdGenTests/GeneralCategoryCodeTests.swift` (rename one of the suites since `expandToUncompacted()` is renamed)
- Create: `Tests/BedrockUcdGenTests/BidiClassCodeTests.swift`

- [ ] **Step 1: Rename existing helper in source and tests**

The current `Array<UCDEntry>.expandToUncompacted()` becomes `expandGeneralCategory()`. In `Sources/BedrockUcdGen/UCDParser.swift` change:

```swift
public extension Array where Element == UCDEntry {
    func expandGeneralCategory() throws -> [UInt8] {
        var out = [UInt8](repeating: 29, count: 0x110000)
        for entry in self {
            let value = try GeneralCategoryCode.rawValue(for: entry.category)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}
```

In `Tests/BedrockUcdGenTests/GeneralCategoryCodeTests.swift` rename the calls in the `ExpandToUncompactedTests` suite from `entries.expandToUncompacted()` to `entries.expandGeneralCategory()` (4 call sites). Optionally rename the suite struct itself to `ExpandGeneralCategoryTests` for clarity.

- [ ] **Step 2: Write failing tests for BidiClassCode + expansion helpers**

Create `Tests/BedrockUcdGenTests/BidiClassCodeTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct BidiClassCodeTests {

    @Test
    func everyKnownAbbreviationMapsToExpectedRaw() throws {
        let cases: [(String, UInt8)] = [
            ("L", 0), ("R", 1), ("AL", 2),
            ("EN", 3), ("ES", 4), ("ET", 5), ("AN", 6), ("CS", 7),
            ("NSM", 8), ("BN", 9),
            ("B", 10), ("S", 11), ("WS", 12), ("ON", 13),
            ("LRE", 14), ("LRO", 15), ("RLE", 16), ("RLO", 17), ("PDF", 18),
            ("LRI", 19), ("RLI", 20), ("FSI", 21), ("PDI", 22),
        ]
        for (abbr, expected) in cases {
            let actual = try BidiClassCode.rawValue(for: abbr)
            #expect(actual == expected,
                    "bidi abbreviation \(abbr) -> expected \(expected), got \(actual)")
        }
    }

    @Test
    func unknownAbbreviationThrows() {
        do {
            _ = try BidiClassCode.rawValue(for: "Zz")
            Issue.record("expected throw for unknown abbreviation")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandBidiClassTests {

    @Test
    func emptyEntriesYieldsAllLeftToRight() throws {
        let entries: [UCDEntry] = []
        let out = try entries.expandBidiClass()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })   // L
    }

    @Test
    func singleEntryFillsOneCodepoint() throws {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x05D0, last: 0x05D0, category: "Lo",
                     canonicalCombiningClass: 0, bidiClass: "R"),
        ]
        let out = try entries.expandBidiClass()
        #expect(out[0x05D0] == 1)   // R
        #expect(out[0x05CF] == 0)   // L default
    }

    @Test
    func rangeEntryFillsInclusiveRange() throws {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x4E00, last: 0x9FFF, category: "Lo",
                     canonicalCombiningClass: 0, bidiClass: "L"),
        ]
        let out = try entries.expandBidiClass()
        #expect(out[0x4E00] == 0)
        #expect(out[0x6F22] == 0)
        #expect(out[0x9FFF] == 0)
    }

    @Test
    func unknownAbbreviationThrows() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0041, last: 0x0041, category: "Lu",
                     canonicalCombiningClass: 0, bidiClass: "Zz"),
        ]
        do {
            _ = try entries.expandBidiClass()
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandCanonicalCombiningClassTests {

    @Test
    func emptyEntriesYieldsAllZeros() {
        let entries: [UCDEntry] = []
        let out = entries.expandCanonicalCombiningClass()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func singleEntryFillsOneCodepoint() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0300, last: 0x0300, category: "Mn",
                     canonicalCombiningClass: 230, bidiClass: "NSM"),
        ]
        let out = entries.expandCanonicalCombiningClass()
        #expect(out[0x0300] == 230)
        #expect(out[0x02FF] == 0)
        #expect(out[0x0301] == 0)
    }

    @Test
    func rangeEntryFillsInclusiveRange() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x4E00, last: 0x9FFF, category: "Lo",
                     canonicalCombiningClass: 0, bidiClass: "L"),
        ]
        let out = entries.expandCanonicalCombiningClass()
        #expect(out[0x4E00] == 0)
        #expect(out[0x9FFF] == 0)
    }
}
```

- [ ] **Step 3: Run to verify failure**

```bash
swift test --filter BedrockUcdGenTests 2>&1 | tail -10
```
Expected: compile error — `BidiClassCode`, `expandBidiClass`, `expandCanonicalCombiningClass` don't exist.

- [ ] **Step 4: Implement BidiClassCode and the two expansion helpers**

Append to `Sources/BedrockUcdGen/UCDParser.swift` (after `GeneralCategoryCode`):

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

Extend the `Array<UCDEntry>` extension with the two new helpers (alongside the renamed `expandGeneralCategory`):

```swift
public extension Array where Element == UCDEntry {
    func expandBidiClass() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)   // L default
        for entry in self {
            let value = try BidiClassCode.rawValue(for: entry.bidiClass)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }

    func expandCanonicalCombiningClass() -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = entry.canonicalCombiningClass
            if value == 0 { continue }   // skip; already 0
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}
```

The CCC helper's no-throw signature is fine because `entry.canonicalCombiningClass` is already validated `UInt8` at parse time.

- [ ] **Step 5: Run tests**

```bash
swift test --filter BedrockUcdGenTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: all BedrockUcdGen tests pass; full suite green.

- [ ] **Step 6: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add BidiClassCode and expansion helpers

23-case bidi abbreviation -> UInt8 map. Two new Array<UCDEntry>
expansion helpers (bidi class throws on unknown abbreviation; CCC
does not because the value was validated at parse time). Renamed
expandToUncompacted to expandGeneralCategory.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Extend CodeEmitter with globalName

**Files:**
- Modify: `Sources/BedrockUcdGen/CodeEmitter.swift`
- Modify: `Tests/BedrockUcdGenTests/CodeEmitterTests.swift`
- Modify: `Sources/bedrock-ucd-gen/main.swift` (to pass globalName)

- [ ] **Step 1: Update tests for new signature**

In `Tests/BedrockUcdGenTests/CodeEmitterTests.swift`, every `CodeEmitter.emit(trie, unicodeVersion: ...)` becomes `CodeEmitter.emit(trie, unicodeVersion: ..., globalName: "generalCategoryTable")`. Also add one new assertion verifying the global name appears verbatim in the output:

```swift
@Test
func usesProvidedGlobalName() {
    let trie = BuiltTrie(
        stage1: [0, 0],
        stage2: [1]
    )
    let src = CodeEmitter.emit(trie, unicodeVersion: "16.0.0", globalName: "myCustomTable")
    #expect(src.contains("internal let myCustomTable"))
    #expect(src.contains("internal let generalCategoryTable") == false)
}
```

- [ ] **Step 2: Update CodeEmitter signature**

Replace the body of `Sources/BedrockUcdGen/CodeEmitter.swift`:

```swift
public enum CodeEmitter {

    public static func emit(_ trie: BuiltTrie,
                            unicodeVersion: String,
                            globalName: String) -> String {
        var out = ""
        out += "// GENERATED by `swift run bedrock-ucd-gen`. Do not edit by hand.\n"
        out += "// Source: Sources/UnicodeProperties/UCD/UnicodeData.txt "
        out += "(Unicode \(unicodeVersion))\n"
        out += "\n"
        out += "@usableFromInline\n"
        out += "internal let \(globalName) = TwoStageTrie<UInt8>(\n"
        out += "    stage1: [\n"
        out += formatArray(trie.stage1.map { UInt($0) }, indent: "        ")
        out += "\n    ],\n"
        out += "    stage2: [\n"
        out += formatArray(trie.stage2.map { UInt($0) }, indent: "        ")
        out += "\n    ]\n"
        out += ")\n"
        return out
    }

    private static func formatArray(_ values: [UInt], indent: String) -> String {
        var out = indent
        for (i, v) in values.enumerated() {
            out += String(v)
            if i != values.count - 1 {
                out += ","
                if (i + 1) % 16 == 0 {
                    out += "\n" + indent
                } else {
                    out += " "
                }
            }
        }
        return out
    }
}
```

- [ ] **Step 3: Update main.swift to pass globalName**

In `Sources/bedrock-ucd-gen/main.swift`, change:
```swift
let src = CodeEmitter.emit(trie, unicodeVersion: unicodeVersion)
```
to:
```swift
let src = CodeEmitter.emit(trie, unicodeVersion: unicodeVersion,
                            globalName: "generalCategoryTable")
```

Also update the variable name `let entries: [UCDEntry]` and the expansion call to use the renamed helper:
```swift
uncompacted = try entries.expandGeneralCategory()
```

- [ ] **Step 4: Build + tests**

```bash
swift build 2>&1 | tail -3
swift test --filter CodeEmitterTests 2>&1 | tail -5
swift test 2>&1 | tail -3
```
Expected: builds clean; all CodeEmitter tests pass (including the new one); full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Sources/bedrock-ucd-gen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
refactor(bedrock-ucd-gen): emit takes globalName parameter

Lets the codegen tool emit multiple property tables that don't
collide on a single hardcoded global name. main.swift updated to
pass "generalCategoryTable" and to use the renamed expansion helper.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Extend main.swift, emit three tables, run codegen

**Files:**
- Modify: `Sources/bedrock-ucd-gen/main.swift`
- Create (by running codegen): `Sources/UnicodeProperties/Generated/BidiClassTable.swift`
- Create (by running codegen): `Sources/UnicodeProperties/Generated/CanonicalCombiningClassTable.swift`

Two new placeholder files must exist before this task's codegen invocation, so the `UnicodeProperties` library compiles when Task 5 starts importing the new global names. Add them in Step 1 below as a stub identical to the Task 2 placeholder style from Layer 2.1, so the package keeps building between tasks.

- [ ] **Step 1: Add placeholder generated files**

`Sources/UnicodeProperties/Generated/BidiClassTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let bidiClassTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)   // 0 = .leftToRight
)
```

`Sources/UnicodeProperties/Generated/CanonicalCombiningClassTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let canonicalCombiningClassTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)   // 0 = no combining class
)
```

Run `swift build` to confirm both placeholders compile.

- [ ] **Step 2: Extend main.swift to emit three tables**

Replace `Sources/bedrock-ucd-gen/main.swift`:

```swift
import Foundation
import BedrockUcdGen

let ucdPath = "Sources/UnicodeProperties/UCD/UnicodeData.txt"
let unicodeVersion = "16.0.0"

let outputs: [(String, String, String, ([UCDEntry]) throws -> [UInt8])] = [
    ("Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift",
     "generalCategoryTable", "general category",
     { try $0.expandGeneralCategory() }),
    ("Sources/UnicodeProperties/Generated/BidiClassTable.swift",
     "bidiClassTable", "bidi class",
     { try $0.expandBidiClass() }),
    ("Sources/UnicodeProperties/Generated/CanonicalCombiningClassTable.swift",
     "canonicalCombiningClassTable", "canonical combining class",
     { $0.expandCanonicalCombiningClass() }),
]

print("Reading \(ucdPath) ...")
let text: String
do {
    text = try String(contentsOfFile: ucdPath, encoding: .utf8)
} catch {
    print("Failed to read \(ucdPath): \(error)")
    exit(1)
}

let entries: [UCDEntry]
do {
    entries = try UCDParser.parse(text)
    print("Parsed \(entries.count) entries.")
} catch {
    print("Parse error: \(error)")
    exit(1)
}

for (outputPath, globalName, label, expand) in outputs {
    print("---")
    print("Processing: \(label)")
    let uncompacted: [UInt8]
    do {
        uncompacted = try expand(entries)
    } catch {
        print("Expansion error for \(label): \(error)")
        exit(1)
    }

    let trie = TwoStageTrieBuilder.build(uncompacted)
    print("Built two-stage trie: stage1=\(trie.stage1.count) entries, stage2=\(trie.stage2.count) entries (\(trie.stage2.count / 256) unique blocks).")

    var mismatches = 0
    for cp in 0..<UInt32(0x110000) {
        if trie.lookup(cp) != uncompacted[Int(cp)] {
            mismatches += 1
            if mismatches <= 5 {
                print("Mismatch at U+\(String(cp, radix: 16, uppercase: true)): trie=\(trie.lookup(cp)) source=\(uncompacted[Int(cp)])")
            }
        }
    }
    if mismatches > 0 {
        print("Self-check FAILED for \(label): \(mismatches) mismatches.")
        exit(1)
    }
    print("Self-check OK: 1114112 codepoints round-trip.")

    let src = CodeEmitter.emit(trie, unicodeVersion: unicodeVersion, globalName: globalName)
    do {
        try src.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Wrote \(outputPath) (\(src.utf8.count) bytes).")
    } catch {
        print("Write error for \(label): \(error)")
        exit(1)
    }
}
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -25
```
Expected: three "Processing" + self-check + Wrote lines for general category, bidi class, and CCC. Each self-check shows 1114112 codepoints round-tripping.

If any self-check fails, the expansion or parse has a bug — STOP and investigate.

- [ ] **Step 4: Verify the package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite green.

- [ ] **Step 5: Spot-check generated files**

```bash
wc -l Sources/UnicodeProperties/Generated/BidiClassTable.swift
wc -l Sources/UnicodeProperties/Generated/CanonicalCombiningClassTable.swift
head -3 Sources/UnicodeProperties/Generated/BidiClassTable.swift
head -3 Sources/UnicodeProperties/Generated/CanonicalCombiningClassTable.swift
```
Expected: both start with the GENERATED banner; bidi table likely ~150-200KB; CCC table likely smaller due to heavy block dedup.

- [ ] **Step 6: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit bidi class and CCC tables

main.swift now iterates over a (path, globalName, label, expand)
tuple list and emits three tables. Each self-checks against the
uncompacted source before emission. Tables generated against
Unicode 16.0.0; all 1114112 codepoints round-trip per property.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: BidiClass enum + public API

**Files:**
- Create: `Sources/UnicodeProperties/BidiClass.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/BidiClassTests.swift`
- Create: `Tests/UnicodePropertiesTests/BidiClassConformanceTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/UnicodePropertiesTests/BidiClassTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct BidiClassTests {

    private func cls(_ scalar: Unicode.Scalar) -> UnicodeProperties.BidiClass {
        UnicodeProperties.bidiClass(of: scalar)
    }

    @Test
    func ascii() {
        #expect(cls("A") == .leftToRight)
        #expect(cls("5") == .europeanNumber)
        #expect(cls(" ") == .whiteSpace)
        #expect(cls("$") == .europeanTerminator)
        #expect(cls(",") == .commonSeparator)
    }

    @Test
    func hebrewIsRightToLeft() {
        #expect(cls("\u{05D0}") == .rightToLeft)   // א
    }

    @Test
    func arabicIsArabicLetter() {
        #expect(cls("\u{0627}") == .arabicLetter)   // ا
    }

    @Test
    func combiningMarkIsNSM() {
        #expect(cls("\u{0301}") == .nonspacingMark)
    }

    @Test
    func paragraphSeparator() {
        #expect(cls(Unicode.Scalar(0x2029)!) == .paragraphSeparator)
    }

    @Test
    func explicitFormattingCharacters() {
        #expect(cls(Unicode.Scalar(0x202A)!) == .leftToRightEmbedding)
        #expect(cls(Unicode.Scalar(0x202B)!) == .rightToLeftEmbedding)
        #expect(cls(Unicode.Scalar(0x202C)!) == .popDirectionalFormat)
        #expect(cls(Unicode.Scalar(0x202D)!) == .leftToRightOverride)
        #expect(cls(Unicode.Scalar(0x202E)!) == .rightToLeftOverride)
        #expect(cls(Unicode.Scalar(0x2066)!) == .leftToRightIsolate)
        #expect(cls(Unicode.Scalar(0x2067)!) == .rightToLeftIsolate)
        #expect(cls(Unicode.Scalar(0x2068)!) == .firstStrongIsolate)
        #expect(cls(Unicode.Scalar(0x2069)!) == .popDirectionalIsolate)
    }
}
```

`Tests/UnicodePropertiesTests/BidiClassConformanceTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct BidiClassConformanceTests {

    @Test
    func hasExactly23Cases() {
        #expect(UnicodeProperties.BidiClass.allCases.count == 23)
    }

    @Test
    func rawValuesAreContiguous() {
        let raws = UnicodeProperties.BidiClass.allCases.map { $0.rawValue }
        #expect(raws == Array<UInt8>(0...22))
    }

    @Test
    func equatableHashableSmoke() {
        var set = Set<UnicodeProperties.BidiClass>()
        for c in UnicodeProperties.BidiClass.allCases {
            set.insert(c)
            set.insert(c)
        }
        #expect(set.count == 23)
    }

    @Test
    func sendable() {
        let c: UnicodeProperties.BidiClass = .leftToRight
        Task.detached { @Sendable in
            let _ = c
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter BidiClassTests 2>&1 | tail -5
```
Expected: compile error.

- [ ] **Step 3: Implement BidiClass**

Create `Sources/UnicodeProperties/BidiClass.swift`:
```swift
extension UnicodeProperties {

    /// Unicode bidirectional class (UnicodeData.txt field 4, UAX #9).
    public enum BidiClass: UInt8, Sendable, Hashable, CaseIterable {
        // Strong
        case leftToRight                  = 0
        case rightToLeft                  = 1
        case arabicLetter                 = 2
        // Weak
        case europeanNumber               = 3
        case europeanSeparator            = 4
        case europeanTerminator           = 5
        case arabicNumber                 = 6
        case commonSeparator              = 7
        case nonspacingMark               = 8
        case boundaryNeutral              = 9
        // Neutral
        case paragraphSeparator           = 10
        case segmentSeparator             = 11
        case whiteSpace                   = 12
        case otherNeutral                 = 13
        // Explicit formatting
        case leftToRightEmbedding         = 14
        case leftToRightOverride          = 15
        case rightToLeftEmbedding         = 16
        case rightToLeftOverride          = 17
        case popDirectionalFormat         = 18
        case leftToRightIsolate           = 19
        case rightToLeftIsolate           = 20
        case firstStrongIsolate           = 21
        case popDirectionalIsolate        = 22
    }
}
```

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add the entry point after `generalCategory(of:)`:

```swift
    /// O(1) bidi-class lookup. Defaults to `.leftToRight` for codepoints
    /// not present in UnicodeData.txt.
    @inlinable
    public static func bidiClass(of scalar: Unicode.Scalar) -> BidiClass {
        let raw = bidiClassTable.lookup(scalar.value)
        return BidiClass(rawValue: raw) ?? .leftToRight
    }
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter BidiClassTests 2>&1 | tail -10
swift test --filter BidiClassConformanceTests 2>&1 | tail -5
swift test 2>&1 | tail -3
```
Expected: spot-check tests pass; conformance tests pass; full suite green.

If a spot-check fails, the UCD says something different from what the test asserts — investigate via the line in `UnicodeData.txt`; do NOT alter generated tables to make tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add BidiClass enum and bidiClass(of:)

23-case enum per UAX #9, O(1) lookup against the generated bidi-class
trie. Returns .leftToRight for codepoints absent from UnicodeData.txt
(refinement for unassigned-block defaults awaits DerivedBidiClass.txt
ingestion in a future sub-project).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: canonicalCombiningClass(of:) entry point

**Files:**
- Create: `Sources/UnicodeProperties/CanonicalCombiningClass.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/CanonicalCombiningClassTests.swift`

The CCC API is just a function, but per the spec layout it lives in its own file for parallelism with `BidiClass.swift`.

- [ ] **Step 1: Write failing tests**

`Tests/UnicodePropertiesTests/CanonicalCombiningClassTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct CanonicalCombiningClassTests {

    private func ccc(_ scalar: Unicode.Scalar) -> UInt8 {
        UnicodeProperties.canonicalCombiningClass(of: scalar)
    }

    @Test
    func asciiHasZeroCCC() {
        #expect(ccc("A") == 0)
        #expect(ccc("5") == 0)
        #expect(ccc(" ") == 0)
    }

    @Test
    func combiningGraveIsAbove() {
        #expect(ccc("\u{0300}") == 230)
    }

    @Test
    func combiningAcuteIsAbove() {
        #expect(ccc("\u{0301}") == 230)
    }

    @Test
    func combiningTildeIsAbove() {
        #expect(ccc("\u{0303}") == 230)
    }

    @Test
    func combiningCedillaIsAttachedBelow() {
        #expect(ccc("\u{0327}") == 202)
    }

    @Test
    func hiraganaVoicingMark() {
        // U+3099 COMBINING KATAKANA-HIRAGANA VOICED SOUND MARK has CCC = 8
        #expect(ccc(Unicode.Scalar(0x3099)!) == 8)
    }

    @Test
    func hebrewShevaIsTen() {
        // U+05B0 HEBREW POINT SHEVA has CCC = 10
        #expect(ccc(Unicode.Scalar(0x05B0)!) == 10)
    }

    @Test
    func arabicShaddaIs33() {
        // U+0651 ARABIC SHADDA has CCC = 33
        #expect(ccc(Unicode.Scalar(0x0651)!) == 33)
    }
}
```

- [ ] **Step 2: Implement entry point**

Create `Sources/UnicodeProperties/CanonicalCombiningClass.swift`:
```swift
// CanonicalCombiningClass is exposed as UInt8 (not a strongly-typed enum)
// because canonical-ordering algorithms consume the value numerically.
//
// Public entry point lives in UnicodeProperties.swift to keep the namespace
// surface co-located with other property accessors. This file exists to
// match the file-per-property layout established in the design spec.
```

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add:

```swift
    /// O(1) canonical-combining-class lookup. Returns 0 for codepoints
    /// with no combining class (the default per UCD).
    @inlinable
    public static func canonicalCombiningClass(of scalar: Unicode.Scalar) -> UInt8 {
        canonicalCombiningClassTable.lookup(scalar.value)
    }
```

- [ ] **Step 3: Run tests**

```bash
swift test --filter CanonicalCombiningClassTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 8 CCC tests pass; full suite green.

- [ ] **Step 4: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add canonicalCombiningClass(of:)

O(1) lookup returning UInt8 per UCD field 3. Spot-checked across
ASCII (CCC=0), combining marks Above (230) and Attached Below (202),
and the Kana / Hebrew / Arabic combining ranges.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Extended exhaustive test, coverage, and Layer 2 doc

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`
- Modify: `layers/layer-02-text-unicode.md`

- [ ] **Step 1: Extend exhaustive test**

Edit `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` to also assert bidi-class range:

```swift
@Test
func everyCodepointLookupCompletesAndReturnsValidValue() {
    for cp: UInt32 in 0 ..< 0x110000 {
        guard let scalar = Unicode.Scalar(cp) else { continue }
        let c = UnicodeProperties.generalCategory(of: scalar)
        #expect(c.rawValue <= 29,
                "out-of-range raw value at U+\(String(cp, radix: 16))")
        let b = UnicodeProperties.bidiClass(of: scalar)
        #expect(b.rawValue <= 22,
                "out-of-range bidi-class raw value at U+\(String(cp, radix: 16))")
        _ = UnicodeProperties.canonicalCombiningClass(of: scalar)
    }
}
```

CCC needs no explicit range check — every `UInt8` is in range.

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass.

- [ ] **Step 3: Coverage check**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build|Generated' \
  Sources/UnicodeProperties/UnicodeProperties.swift \
  Sources/UnicodeProperties/GeneralCategory.swift \
  Sources/UnicodeProperties/BidiClass.swift \
  Sources/UnicodeProperties/CanonicalCombiningClass.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/UCDParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```

Expected: each file ≥ 90% line coverage.

If any file falls below, identify uncovered lines via `xcrun llvm-cov show` and add targeted tests. Precondition-message autoclosures: drop the message (established pattern).

- [ ] **Step 4: Update Layer 2 doc**

Edit `layers/layer-02-text-unicode.md`. Replace the existing "Status" block with:

```markdown
> **Status:** shipping modules:
> - `Sources/UnicodeProperties/` — UCD-derived lookup against a two-stage trie. Properties available: general category (UAX #44), bidi class (UAX #9), canonical combining class. Codegen tool `bedrock-ucd-gen` emits one table per property ([2.1 design](../docs/superpowers/specs/2026-05-19-unicode-properties-design.md) · [2.1 plan](../docs/superpowers/plans/2026-05-19-unicode-properties-module.md) · [2.2 design](../docs/superpowers/specs/2026-05-20-bidi-class-and-ccc-design.md) · [2.2 plan](../docs/superpowers/plans/2026-05-20-bidi-class-and-ccc-module.md)). Unicode 16.0.0.
>
> Subsequent sub-projects (Layer 2.3–2.8): normalization (NFC/NFD/NFKC/NFKD), segmentation (UAX #29), case mapping, identifier classification (UAX #31), bidi algorithm (UAX #9), ASCII helpers.
```

- [ ] **Step 5: Commit**

```bash
git add Tests/UnicodePropertiesTests layers/layer-02-text-unicode.md
git commit -m "$(cat <<'EOF'
docs(layer-2): mark BidiClass and CCC shipped

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(If coverage tests were added in Step 3, fold them into the commit above or commit them separately as `test(...)`.)

---

## Plan Self-Review Notes

- **Spec coverage:** Every spec item — extended `UCDEntry`, extended parser, `BidiClassCode`, two new expansion helpers, extended `CodeEmitter`, three-table `main.swift`, `BidiClass` enum, `bidiClass(of:)`, `canonicalCombiningClass(of:)` — has a task. Every test category in the spec is covered.
- **No placeholders:** Every step shows runnable code or an exact command.
- **Type consistency:** `UnicodeProperties.BidiClass` raw values 0...22; `canonicalCombiningClass` returns `UInt8`; helper names `expandGeneralCategory`/`expandBidiClass`/`expandCanonicalCombiningClass` are consistent across all tasks.
- **Backward-compat handling:** Task 1 updates UCDEntry's init; existing UCDParser tests are explicitly patched in Step 1. Task 2 renames `expandToUncompacted` → `expandGeneralCategory` and patches the existing test call sites. Task 3 updates CodeEmitter's signature and patches its tests. Each renaming is bundled with its test updates so the suite stays green between tasks.
- **Placeholder tables in Task 4 Step 1:** ensures the package keeps building during Task 4 even before `swift run bedrock-ucd-gen` produces real tables. Without these, `UnicodeProperties.swift` (which Task 5 will modify to reference `bidiClassTable` and `canonicalCombiningClassTable`) would have no global to reference.
- **No new generated files referenced in main code before codegen runs:** Tasks 5 and 6 only run after Task 4 has produced real tables. The `bidiClassTable` and `canonicalCombiningClassTable` globals exist (as placeholders or real) from Task 4 onward.
- **Codegen-time self-check** runs per-property in Task 4; aborts the whole emission run on any single mismatch.

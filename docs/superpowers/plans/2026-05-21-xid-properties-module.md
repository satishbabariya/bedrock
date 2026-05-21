# XID Identifier Properties Implementation Plan (Layer 2.5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.isXIDStart(_:)` and `isXIDContinue(_:)` per the spec at `docs/superpowers/specs/2026-05-21-xid-properties-design.md`. Introduce a third UCD parser (`DerivedCorePropertyParser`) consuming the already-vendored `DerivedCoreProperties.txt`.

**Architecture:** Property-name-agnostic parser yields `[DerivedCorePropertyEntry]`. Two expansion helpers filter by name and produce `[UInt8]` (0/1 per codepoint). The existing generic `TwoStageTrieBuilder.build` and `CodeEmitter.emit` produce two new tables. Two new `@inlinable` entry points.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/bedrock-ucd-gen/main.swift` — add a single parse step + two emission steps after the existing CaseFolding step.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add two new entry points.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — sweep the two new entry points.

**Creations:**
- `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift`
- `Sources/UnicodeProperties/Identifier.swift` (comment-only marker)
- `Sources/UnicodeProperties/Generated/XIDStartTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/XIDContinueTable.swift` (placeholder, then real)
- `Tests/UnicodePropertiesTests/IdentifierTests.swift`
- `Tests/BedrockUcdGenTests/DerivedCorePropertyParserTests.swift`
- `Tests/BedrockUcdGenTests/ExpandXIDPropertiesTests.swift`

The vendored `Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt` is already committed (separate prior commit).

---

## Task 1: DerivedCorePropertyParser

**Files:**
- Create: `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift`
- Create: `Tests/BedrockUcdGenTests/DerivedCorePropertyParserTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/DerivedCorePropertyParserTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct DerivedCorePropertyParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "005F          ; XID_Continue # Pc       LOW LINE\n"
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x005F)
        #expect(entries[0].last == 0x005F)
        #expect(entries[0].propertyName == "XID_Continue")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "0041..005A    ; XID_Start # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z\n"
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0041)
        #expect(entries[0].last == 0x005A)
        #expect(entries[0].propertyName == "XID_Start")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # DerivedCoreProperties header

        # Section comment

        0041..005A    ; XID_Start # comment

        005F          ; XID_Continue # comment
        """
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].propertyName == "XID_Start")
        #expect(entries[1].propertyName == "XID_Continue")
    }

    @Test
    func parsesMultiplePropertiesForSameRange() throws {
        let input = """
        0041..005A    ; XID_Start # comment
        0041..005A    ; XID_Continue # comment
        0041..005A    ; Alphabetic # comment
        """
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 3)
        #expect(entries[0].propertyName == "XID_Start")
        #expect(entries[1].propertyName == "XID_Continue")
        #expect(entries[2].propertyName == "Alphabetic")
        for e in entries {
            #expect(e.first == 0x0041)
            #expect(e.last == 0x005A)
        }
    }

    @Test
    func handlesRealisticInputWithHeader() throws {
        let input = """
        # DerivedCoreProperties-16.0.0.txt
        # Date: 2024-05-31, 18:09:32 GMT

        # ================================================

        # Derived Property: Math
        #  Generated from: Sm + Other_Math

        002B          ; Math # Sm       PLUS SIGN
        003C..003E    ; Math # Sm   [3] LESS-THAN SIGN..GREATER-THAN SIGN
        """
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].first == 0x002B)
        #expect(entries[0].last == 0x002B)
        #expect(entries[1].first == 0x003C)
        #expect(entries[1].last == 0x003E)
        for e in entries {
            #expect(e.propertyName == "Math")
        }
    }

    @Test
    func rejectsInvalidRange() {
        let input = "0041..        ; XID_Start # comment\n"
        do {
            _ = try DerivedCorePropertyParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX          ; XID_Start # comment\n"
        do {
            _ = try DerivedCorePropertyParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyName() {
        let input = "0041          ; # comment\n"
        do {
            _ = try DerivedCorePropertyParser.parse(input)
            Issue.record("expected throw for empty property name")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0041\n"
        do {
            _ = try DerivedCorePropertyParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter DerivedCorePropertyParserTests 2>&1 | tail -10
```
Expected: compile error — `DerivedCorePropertyParser`, `DerivedCorePropertyEntry` don't exist.

- [ ] **Step 3: Implement the parser**

Create `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift`:
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

public enum DerivedCorePropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyName(lineNumber: Int)
}

public enum DerivedCorePropertyParser {

    public static func parse(_ text: String) throws -> [DerivedCorePropertyEntry] {
        var entries: [DerivedCorePropertyEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.dcpTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw DerivedCorePropertyParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).dcpTrimmed()
            let nameField  = String(fields[1]).dcpTrimmed()

            if nameField.isEmpty {
                throw DerivedCorePropertyParseError.emptyPropertyName(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.range(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).dcpTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).dcpTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr, radix: 16) else {
                    throw DerivedCorePropertyParseError.invalidRange(lineNumber: lineNumber,
                                                                      raw: rangeField)
                }
                first = f
                last = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw DerivedCorePropertyParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                          raw: rangeField)
                }
                first = cp
                last = cp
            }

            entries.append(DerivedCorePropertyEntry(first: first,
                                                     last: last,
                                                     propertyName: nameField))
        }
        return entries
    }
}

private extension String {
    func dcpTrimmed() -> String {
        var startIdx = self.startIndex
        while startIdx < self.endIndex,
              [" ", "\t", "\r"].contains(self[startIdx]) {
            startIdx = self.index(after: startIdx)
        }
        var endIdx = self.endIndex
        while endIdx > startIdx {
            let prev = self.index(before: endIdx)
            if ![" ", "\t", "\r"].contains(self[prev]) { break }
            endIdx = prev
        }
        return String(self[startIdx..<endIdx])
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter DerivedCorePropertyParserTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 9 parser tests pass; full suite green at 653.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add DerivedCorePropertyParser

Parses DerivedCoreProperties.txt UCD format (range-or-codepoint ;
property-name # comment). Property-name-agnostic: returns all entries
unfiltered. Structured errors for malformed inputs. Stdlib-only
whitespace trimming local to the file.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: expandXIDStart + expandXIDContinue

**Files:**
- Modify: `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift` (append the extension)
- Create: `Tests/BedrockUcdGenTests/ExpandXIDPropertiesTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/BedrockUcdGenTests/ExpandXIDPropertiesTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandXIDStartTests {

    @Test
    func emptyEntriesYieldsAllZeros() {
        let entries: [DerivedCorePropertyEntry] = []
        let out = entries.expandXIDStart()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func singleCodepointEntrySetsOne() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x0041,
                                       propertyName: "XID_Start"),
        ]
        let out = entries.expandXIDStart()
        #expect(out[0x0041] == 1)
        #expect(out[0x0040] == 0)
        #expect(out[0x0042] == 0)
    }

    @Test
    func rangeEntryFillsInclusiveRange() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x005A,
                                       propertyName: "XID_Start"),
        ]
        let out = entries.expandXIDStart()
        #expect(out[0x0040] == 0)
        #expect(out[0x0041] == 1)
        #expect(out[0x0050] == 1)
        #expect(out[0x005A] == 1)
        #expect(out[0x005B] == 0)
    }

    @Test
    func entryWithDifferentPropertyIsSkipped() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x0041,
                                       propertyName: "Math"),
        ]
        let out = entries.expandXIDStart()
        #expect(out[0x0041] == 0)
    }
}

@Suite
struct ExpandXIDContinueTests {

    @Test
    func picksUpOnlyXIDContinue() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x005A,
                                       propertyName: "XID_Start"),
            DerivedCorePropertyEntry(first: 0x005F, last: 0x005F,
                                       propertyName: "XID_Continue"),
            DerivedCorePropertyEntry(first: 0x002B, last: 0x002B,
                                       propertyName: "Math"),
        ]
        let out = entries.expandXIDContinue()
        #expect(out[0x0041] == 0)   // XID_Start, not Continue
        #expect(out[0x005F] == 1)   // XID_Continue
        #expect(out[0x002B] == 0)   // Math, not Continue
    }

    @Test
    func startAndContinueOnSameRangeAreIndependent() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x005A,
                                       propertyName: "XID_Start"),
            DerivedCorePropertyEntry(first: 0x0041, last: 0x005A,
                                       propertyName: "XID_Continue"),
        ]
        let startOut = entries.expandXIDStart()
        let contOut = entries.expandXIDContinue()
        #expect(startOut[0x0041] == 1)
        #expect(contOut[0x0041] == 1)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter ExpandXID 2>&1 | tail -10
```
Expected: compile error.

- [ ] **Step 3: Implement the helpers**

In `Sources/BedrockUcdGen/DerivedCorePropertyParser.swift`, append the extension AFTER the parser enum and BEFORE the private `String.dcpTrimmed` extension:

```swift
public extension Array where Element == DerivedCorePropertyEntry {
    /// XID_Start: valid identifier-start codepoints per UAX #31.
    func expandXIDStart() -> [UInt8] {
        expand(matching: "XID_Start")
    }

    /// XID_Continue: valid identifier-continuation codepoints per UAX #31.
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

- [ ] **Step 4: Run tests**

```bash
swift test --filter ExpandXID 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 6 helper tests pass; full suite green at 659.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add expandXIDStart and expandXIDContinue helpers

Each filters DerivedCorePropertyEntry list by name and writes 1
across the inclusive range. Private generic expand(matching:) helper
keeps the implementations one-liners.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Codegen run + generated tables

**Files:**
- Create: `Sources/UnicodeProperties/Generated/XIDStartTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/XIDContinueTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated files**

Create `Sources/UnicodeProperties/Generated/XIDStartTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let xidStartTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

Create `Sources/UnicodeProperties/Generated/XIDContinueTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let xidContinueTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

Verify build:
```bash
swift build 2>&1 | tail -3
```

- [ ] **Step 2: Extend main.swift**

Read `Sources/bedrock-ucd-gen/main.swift` first. After the existing CaseFolding emission step (at the very end of the file), append:

```swift
print("---")
print("Parsing DerivedCoreProperties.txt ...")
let dcpPath = "Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt"
let dcpText: String
do {
    dcpText = try String(contentsOfFile: dcpPath, encoding: .utf8)
} catch {
    print("Failed to read \(dcpPath): \(error)")
    exit(1)
}
let dcpEntries: [DerivedCorePropertyEntry]
do {
    dcpEntries = try DerivedCorePropertyParser.parse(dcpText)
    print("Parsed \(dcpEntries.count) DerivedCoreProperty entries.")
} catch {
    print("DerivedCoreProperties parse error: \(error)")
    exit(1)
}

print("---")
print("Processing: XID_Start")
emitUInt8("Sources/UnicodeProperties/Generated/XIDStartTable.swift",
           "xidStartTable", "XID_Start", dcpEntries.expandXIDStart())

print("---")
print("Processing: XID_Continue")
emitUInt8("Sources/UnicodeProperties/Generated/XIDContinueTable.swift",
           "xidContinueTable", "XID_Continue", dcpEntries.expandXIDContinue())
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -25
```
Expected: existing 7 emissions plus 2 new (XID_Start, XID_Continue). Each self-checks against the uncompacted source. Total: ~13K entries parsed from DerivedCoreProperties.txt. Self-check shows 1114112 codepoints round-tripping per property.

If a self-check fails — STOP and report.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite still green at 659 (no public API references the new globals yet).

- [ ] **Step 5: Spot-check the generated files**

```bash
wc -c Sources/UnicodeProperties/Generated/XID*.swift
head -5 Sources/UnicodeProperties/Generated/XIDStartTable.swift
```
Expected: each starts with GENERATED banner; sizes 15-25 KB likely.

- [ ] **Step 6: Verify the other 7 tables are unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: only `XIDStartTable.swift` and `XIDContinueTable.swift` show changes (placeholder → real). No diff on the other 7. If any other shows a diff, STOP and report.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit XID_Start and XID_Continue tables

bedrock-ucd-gen extended with a fourth UCD source: reads
DerivedCoreProperties.txt, parses, emits XIDStartTable.swift and
XIDContinueTable.swift via the existing generic emitter. Per-property
self-check confirms all 1114112 codepoints round-trip.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Public API + spot-check tests

**Files:**
- Create: `Sources/UnicodeProperties/Identifier.swift` (comment-only marker)
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/IdentifierTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/UnicodePropertiesTests/IdentifierTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct IdentifierTests {

    @Test
    func asciiLettersAreStart() {
        #expect(UnicodeProperties.isXIDStart("A"))
        #expect(UnicodeProperties.isXIDStart("Z"))
        #expect(UnicodeProperties.isXIDStart("a"))
        #expect(UnicodeProperties.isXIDStart("z"))
    }

    @Test
    func asciiDigitsAreContinueOnly() {
        #expect(UnicodeProperties.isXIDStart("0") == false)
        #expect(UnicodeProperties.isXIDStart("9") == false)
        #expect(UnicodeProperties.isXIDContinue("0"))
        #expect(UnicodeProperties.isXIDContinue("9"))
    }

    @Test
    func underscoreIsContinueOnly() {
        // U+005F LOW LINE
        #expect(UnicodeProperties.isXIDStart("_") == false)
        #expect(UnicodeProperties.isXIDContinue("_"))
    }

    @Test
    func asciiSpaceAndPunctuationAreNeither() {
        #expect(UnicodeProperties.isXIDStart(" ") == false)
        #expect(UnicodeProperties.isXIDContinue(" ") == false)
        #expect(UnicodeProperties.isXIDStart("!") == false)
        #expect(UnicodeProperties.isXIDContinue("!") == false)
    }

    @Test
    func latin1Letters() {
        // À U+00C0
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x00C0)!))
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x00C0)!))
    }

    @Test
    func middleDotIsContinueOnly() {
        // · U+00B7 MIDDLE DOT — per UAX #31, in XID_Continue but not XID_Start.
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x00B7)!) == false)
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x00B7)!))
    }

    @Test
    func combiningMarksAreContinueOnly() {
        // U+0301 COMBINING ACUTE ACCENT
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x0301)!) == false)
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x0301)!))
    }

    @Test
    func cjkIsBoth() {
        let cjk = Unicode.Scalar(0x6F22)!
        #expect(UnicodeProperties.isXIDStart(cjk))
        #expect(UnicodeProperties.isXIDContinue(cjk))
    }

    @Test
    func greekIsBoth() {
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x03A3)!))
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x03C2)!))
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x03A3)!))
    }

    @Test
    func privateUseAndFormatAreNeither() {
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0xE000)!) == false)
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0xE000)!) == false)
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x200B)!) == false)
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x200B)!) == false)
    }

    @Test
    func startImpliesContinueAcrossSample() {
        let samples: [UInt32] = [0x41, 0x5A, 0x61, 0x7A, 0xC0, 0x03A3,
                                  0x6F22, 0x4E00, 0x10000, 0x1F49,
                                  0x0531, 0x0561]
        for cp in samples {
            let s = Unicode.Scalar(cp)!
            if UnicodeProperties.isXIDStart(s) {
                #expect(UnicodeProperties.isXIDContinue(s),
                        "U+\(String(cp, radix: 16)) is XID_Start but not XID_Continue")
            }
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter IdentifierTests 2>&1 | tail -5
```
Expected: compile error.

- [ ] **Step 3: Create marker file**

Create `Sources/UnicodeProperties/Identifier.swift`:
```swift
// XID identifier classification entry points live in UnicodeProperties.swift
// to keep the namespace surface co-located with other property accessors.
// This file exists to match the file-per-property layout established by
// BidiClass.swift, CanonicalCombiningClass.swift, SimpleCaseMapping.swift,
// and CaseFolding.swift.
```

- [ ] **Step 4: Add the entry points**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add immediately after `caseFolded(of:)` (and before the major-category helpers):

```swift
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
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter IdentifierTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 11 spot-check tests pass; full suite green at 670.

If a spot-check fails, investigate via the corresponding line in `Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt`. Do NOT alter the generated tables or weaken the test.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add isXIDStart and isXIDContinue

UAX #31 identifier classification. ASCII digits and underscore are
XID_Continue but not XID_Start; combining marks likewise; CJK and
Greek are both. Legacy ID_Start/ID_Continue deferred.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Exhaustive sweep + coverage + Layer 2 doc

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`
- Modify: `layers/layer-02-text-unicode.md`

- [ ] **Step 1: Extend exhaustive test**

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add two lines inside the existing per-codepoint loop (after `caseFolded`):
```swift
            _ = UnicodeProperties.isXIDStart(scalar)
            _ = UnicodeProperties.isXIDContinue(scalar)
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: 670 tests pass.

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
  Sources/BedrockUcdGen/CodeEmitter.swift
```
Expected: each file ≥ 90% line coverage.

If `DerivedCorePropertyParser.swift` falls short, identify uncovered lines and add targeted tests (most likely candidates are error-throwing branches the existing reject-tests should already exercise).

- [ ] **Step 4: Update Layer 2 doc**

Edit `layers/layer-02-text-unicode.md`. Replace the existing Status block:

```markdown
> **Status:** shipping modules:
> - `Sources/UnicodeProperties/` — UCD-derived lookup against a two-stage trie. Properties available: general category (UAX #44), bidi class (UAX #9), canonical combining class, simple case mappings (uppercase/lowercase/titlecase), simple case folding (CaseFolding.txt C+S), XID_Start / XID_Continue (UAX #31). Codegen tool `bedrock-ucd-gen` emits one table per property ([2.1 design](../docs/superpowers/specs/2026-05-19-unicode-properties-design.md) · [2.1 plan](../docs/superpowers/plans/2026-05-19-unicode-properties-module.md) · [2.2 design](../docs/superpowers/specs/2026-05-20-bidi-class-and-ccc-design.md) · [2.2 plan](../docs/superpowers/plans/2026-05-20-bidi-class-and-ccc-module.md) · [2.3 design](../docs/superpowers/specs/2026-05-20-simple-case-mapping-design.md) · [2.3 plan](../docs/superpowers/plans/2026-05-20-simple-case-mapping-module.md) · [2.4 design](../docs/superpowers/specs/2026-05-20-simple-case-folding-design.md) · [2.4 plan](../docs/superpowers/plans/2026-05-20-simple-case-folding-module.md) · [2.5 design](../docs/superpowers/specs/2026-05-21-xid-properties-design.md) · [2.5 plan](../docs/superpowers/plans/2026-05-21-xid-properties-module.md)). Unicode 16.0.0.
>
> Subsequent sub-projects (Layer 2.6–2.10): normalization (NFC/NFD/NFKC/NFKD), segmentation (UAX #29), full case folding + SpecialCasing, bidi algorithm (UAX #9), ASCII helpers.
```

- [ ] **Step 5: Commit**

```bash
git add Tests/UnicodePropertiesTests layers/layer-02-text-unicode.md
git commit -m "$(cat <<'EOF'
test+docs(unicode-properties): exhaustive sweep + mark 2.5 shipped

ExhaustiveTests now exercises all nine properties across ~1.1M
codepoints. Layer 2 doc updated to include XID identifier classification.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(If coverage tests were added in Step 3, fold them in or commit separately.)

---

## Plan Self-Review Notes

- **Spec coverage:** every spec item — `DerivedCorePropertyEntry`, `DerivedCorePropertyParser`, two expansion helpers, two generated tables, two entry points — has a task. Every test category in the spec is covered.
- **No placeholders:** every step shows runnable code or an exact command.
- **Type consistency:** `DerivedCorePropertyEntry`'s `first`/`last`/`propertyName` are used identically in parser, helpers, tests. The `expandXIDStart`/`expandXIDContinue` pair uses the same private `expand(matching:)` helper so changes stay in lockstep.
- **Reuses existing infrastructure:** `TwoStageTrieBuilder.build`, `CodeEmitter.emit`, and `emitUInt8` are unchanged. Same pattern as the Layer 2.4 third-emission-step addition.
- **Third UCD source file:** This is the *third* parser the codegen tool maintains (`UCDParser`, `CaseFoldingParser`, `DerivedCorePropertyParser`). Each has its own private trim helper kept file-local to avoid cross-file coupling.
- **Placeholder tables in Task 3 Step 1:** ensures the package keeps building before `swift run bedrock-ucd-gen` produces real tables. Without them, Task 4's API additions wouldn't compile.

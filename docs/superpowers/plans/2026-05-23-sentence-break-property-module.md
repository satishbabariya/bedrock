# Sentence Break Property Implementation Plan (Layer 2.12)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.sentenceBreak(of:)` per the spec at `docs/superpowers/specs/2026-05-23-sentence-break-property-design.md`. Introduce a new parser (`SentenceBreakPropertyParser`) and a new generated table (`SentenceBreakTable.swift`).

**Architecture:** Single-property parser yields `[SentenceBreakPropertyEntry]`. An expansion helper produces `[UInt8]` (values 0–14, default 0 = Other). The existing generic `TwoStageTrieBuilder.build` and `CodeEmitter.emit` produce a new `TwoStageTrie<UInt8>` table. One new `@inlinable` entry point. Fifteen-case `UnicodeProperties.SentenceBreak` enum with `UInt8` raw values.

**Branch:** `layer-2.12-sentence-break`. Commit each task; controller merges.

**Worktree:** `/Users/satishbabariya/Desktop/Bedrock/.worktrees/layer-2.12`

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/bedrock-ucd-gen/main.swift` — append parse + emit step for SentenceBreak at the end.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add `sentenceBreak(of:)` entry point.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — sweep the new entry point.

**Creations:**
- `Sources/BedrockUcdGen/SentenceBreakPropertyParser.swift`
- `Sources/UnicodeProperties/SentenceBreak.swift`
- `Sources/UnicodeProperties/Generated/SentenceBreakTable.swift` (placeholder, then real)
- `Tests/BedrockUcdGenTests/SentenceBreakPropertyParserTests.swift`
- `Tests/BedrockUcdGenTests/ExpandSentenceBreakTests.swift`
- `Tests/UnicodePropertiesTests/SentenceBreakTests.swift`

The vendored `Sources/UnicodeProperties/UCD/SentenceBreakProperty.txt` is already committed.

---

## Task 1: `SentenceBreakPropertyParser`

**Files:**
- Create: `Sources/BedrockUcdGen/SentenceBreakPropertyParser.swift`
- Create: `Tests/BedrockUcdGenTests/SentenceBreakPropertyParserTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/SentenceBreakPropertyParserTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct SentenceBreakPropertyParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "000D          ; CR # Cc       <control-000D>\n"
        let entries = try SentenceBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x000D)
        #expect(entries[0].last  == 0x000D)
        #expect(entries[0].value == "CR")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "0061..007A    ; Lower # L&  [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z\n"
        let entries = try SentenceBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0061)
        #expect(entries[0].last  == 0x007A)
        #expect(entries[0].value == "Lower")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # SentenceBreakProperty-16.0.0.txt
        # @missing: 0000..10FFFF; Other

        000D          ; CR # Cc       <control-000D>

        000A          ; LF # Cc       <control-000A>
        """
        let entries = try SentenceBreakPropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].value == "CR")
        #expect(entries[1].value == "LF")
    }

    @Test
    func parsesRealisticSnippet() throws {
        let input = """
        000D          ; CR # Cc       <control-000D>
        000A          ; LF # Cc       <control-000A>
        0085          ; Sep # Cc       <control-0085>
        0020          ; Sp # Zs       SPACE
        0041..005A    ; Upper # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
        0061..007A    ; Lower # L&  [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z
        """
        let entries = try SentenceBreakPropertyParser.parse(input)
        #expect(entries.count == 6)
        #expect(entries[0].value == "CR")
        #expect(entries[1].value == "LF")
        #expect(entries[2].value == "Sep")
        #expect(entries[2].first == 0x0085)
        #expect(entries[2].last  == 0x0085)
        #expect(entries[3].value == "Sp")
        #expect(entries[4].value == "Upper")
        #expect(entries[4].first == 0x0041)
        #expect(entries[4].last  == 0x005A)
        #expect(entries[5].value == "Lower")
        #expect(entries[5].first == 0x0061)
        #expect(entries[5].last  == 0x007A)
    }

    @Test
    func rejectsTruncatedLine() {
        // No semicolon — only one field.
        let input = "000D\n"
        do {
            _ = try SentenceBreakPropertyParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX          ; CR # comment\n"
        do {
            _ = try SentenceBreakPropertyParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidRange() {
        // Empty second half of range.
        let input = "0061..        ; Lower # comment\n"
        do {
            _ = try SentenceBreakPropertyParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyValue() {
        let input = "000D          ; # Cc comment\n"
        do {
            _ = try SentenceBreakPropertyParser.parse(input)
            Issue.record("expected throw for empty property value")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter SentenceBreakPropertyParserTests 2>&1 | tail -10
```
Expected: compile error — `SentenceBreakPropertyParser`, `SentenceBreakPropertyEntry` don't exist.

- [ ] **Step 3: Implement the parser**

Create `Sources/BedrockUcdGen/SentenceBreakPropertyParser.swift`:
```swift
public struct SentenceBreakPropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "CR", "LF", "Sep", "Extend", "Format",
                                // "Sp", "Lower", "Upper", "OLetter",
                                // "Numeric", "ATerm", "STerm", "SContinue", "Close"

    public init(first: UInt32, last: UInt32, value: String) {
        self.first = first
        self.last  = last
        self.value = value
    }
}

public enum SentenceBreakPropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum SentenceBreakPropertyParser {

    public static func parse(_ text: String) throws -> [SentenceBreakPropertyEntry] {
        var entries: [SentenceBreakPropertyEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.sbpTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw SentenceBreakPropertyParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).sbpTrimmed()
            let valueField = String(fields[1]).sbpTrimmed()

            if valueField.isEmpty {
                throw SentenceBreakPropertyParseError.emptyPropertyValue(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.sbpRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).sbpTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).sbpTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr,  radix: 16) else {
                    throw SentenceBreakPropertyParseError.invalidRange(lineNumber: lineNumber,
                                                                       raw: rangeField)
                }
                first = f
                last  = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw SentenceBreakPropertyParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                           raw: rangeField)
                }
                first = cp
                last  = cp
            }

            entries.append(SentenceBreakPropertyEntry(first: first, last: last, value: valueField))
        }
        return entries
    }
}

private extension String {
    func sbpTrimmed() -> String {
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

    /// Returns the range of the first occurrence of `needle` in `self`,
    /// using only stdlib Character comparisons (no Foundation).
    func sbpRange(of needle: String) -> Range<String.Index>? {
        guard !needle.isEmpty else { return startIndex..<startIndex }
        var i = startIndex
        let needleFirst = needle[needle.startIndex]
        while i < endIndex {
            if self[i] == needleFirst {
                var si = i
                var ni = needle.startIndex
                while ni < needle.endIndex, si < endIndex, self[si] == needle[ni] {
                    si = index(after: si)
                    ni = needle.index(after: ni)
                }
                if ni == needle.endIndex { return i..<si }
            }
            i = index(after: i)
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter SentenceBreakPropertyParserTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 8 parser tests pass; full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add SentenceBreakPropertyParser

Parses SentenceBreakProperty.txt UCD format (codepoint-or-range ;
SB-value # comment). Supports all 14 explicit values (CR, LF, Sep,
Extend, Format, Sp, Lower, Upper, OLetter, Numeric, ATerm, STerm,
SContinue, Close). Structured errors for malformed inputs. Stdlib-only
whitespace/range helpers prefixed sbp to avoid collision with existing
gbp/wbp/eaw/dcp helpers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `SentenceBreakCode` + expansion helper

**Files:**
- Modify: `Sources/BedrockUcdGen/SentenceBreakPropertyParser.swift` (append after the parser enum, before the private String extension)
- Create: `Tests/BedrockUcdGenTests/ExpandSentenceBreakTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/ExpandSentenceBreakTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct SentenceBreakCodeTests {

    @Test
    func allFifteenValuesMapCorrectly() throws {
        #expect(try SentenceBreakCode.rawValue(for: "Other")     == 0)
        #expect(try SentenceBreakCode.rawValue(for: "CR")        == 1)
        #expect(try SentenceBreakCode.rawValue(for: "LF")        == 2)
        #expect(try SentenceBreakCode.rawValue(for: "Sep")       == 3)
        #expect(try SentenceBreakCode.rawValue(for: "Extend")    == 4)
        #expect(try SentenceBreakCode.rawValue(for: "Format")    == 5)
        #expect(try SentenceBreakCode.rawValue(for: "Sp")        == 6)
        #expect(try SentenceBreakCode.rawValue(for: "Lower")     == 7)
        #expect(try SentenceBreakCode.rawValue(for: "Upper")     == 8)
        #expect(try SentenceBreakCode.rawValue(for: "OLetter")   == 9)
        #expect(try SentenceBreakCode.rawValue(for: "Numeric")   == 10)
        #expect(try SentenceBreakCode.rawValue(for: "ATerm")     == 11)
        #expect(try SentenceBreakCode.rawValue(for: "STerm")     == 12)
        #expect(try SentenceBreakCode.rawValue(for: "SContinue") == 13)
        #expect(try SentenceBreakCode.rawValue(for: "Close")     == 14)
    }

    @Test
    func unknownValueThrows() {
        do {
            _ = try SentenceBreakCode.rawValue(for: "XX")
            Issue.record("expected throw for unknown SB value")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandSentenceBreakTests {

    @Test
    func emptyEntriesYieldsAllOther() throws {
        let entries: [SentenceBreakPropertyEntry] = []
        let out = try entries.expandSentenceBreak()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })   // 0 = Other (default)
    }

    @Test
    func singleCREntryFillsOneCodepoint() throws {
        let entries: [SentenceBreakPropertyEntry] = [
            SentenceBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
        ]
        let out = try entries.expandSentenceBreak()
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x000C] == 0)   // untouched = Other
        #expect(out[0x000E] == 0)
    }

    @Test
    func rangeUpperEntryFillsInclusiveRange() throws {
        let entries: [SentenceBreakPropertyEntry] = [
            SentenceBreakPropertyEntry(first: 0x0041, last: 0x005A, value: "Upper"),
        ]
        let out = try entries.expandSentenceBreak()
        #expect(out[0x0040] == 0)   // before range = Other
        #expect(out[0x0041] == 8)   // Upper = 8
        #expect(out[0x004D] == 8)
        #expect(out[0x005A] == 8)
        #expect(out[0x005B] == 0)   // after range = Other
    }

    @Test
    func multipleEntriesWithDifferentValues() throws {
        let entries: [SentenceBreakPropertyEntry] = [
            SentenceBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
            SentenceBreakPropertyEntry(first: 0x000A, last: 0x000A, value: "LF"),
            SentenceBreakPropertyEntry(first: 0x0085, last: 0x0085, value: "Sep"),
            SentenceBreakPropertyEntry(first: 0x0020, last: 0x0020, value: "Sp"),
            SentenceBreakPropertyEntry(first: 0x002E, last: 0x002E, value: "ATerm"),
            SentenceBreakPropertyEntry(first: 0x0021, last: 0x0021, value: "STerm"),
        ]
        let out = try entries.expandSentenceBreak()
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x000A] == 2)   // LF = 2
        #expect(out[0x0085] == 3)   // Sep = 3
        #expect(out[0x0020] == 6)   // Sp = 6
        #expect(out[0x002E] == 11)  // ATerm = 11
        #expect(out[0x0021] == 12)  // STerm = 12
    }

    @Test
    func unknownValueInEntryThrows() {
        let entries: [SentenceBreakPropertyEntry] = [
            SentenceBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "XX"),
        ]
        do {
            _ = try entries.expandSentenceBreak()
            Issue.record("expected throw for unknown SB value")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter SentenceBreakCodeTests 2>&1 | tail -10
swift test --filter ExpandSentenceBreakTests 2>&1 | tail -10
```
Expected: compile errors — `SentenceBreakCode` and `expandSentenceBreak` don't exist.

- [ ] **Step 3: Implement the code mapper and expansion helper**

In `Sources/BedrockUcdGen/SentenceBreakPropertyParser.swift`, append AFTER the `SentenceBreakPropertyParser` enum and BEFORE the private `String` extension:

```swift
public enum SentenceBreakCode {
    /// Map UCD Sentence_Break value to UInt8 raw value matching
    /// UnicodeProperties.SentenceBreak.
    public static func rawValue(for value: String) throws -> UInt8 {
        switch value {
        case "Other":     return 0
        case "CR":        return 1
        case "LF":        return 2
        case "Sep":       return 3
        case "Extend":    return 4
        case "Format":    return 5
        case "Sp":        return 6
        case "Lower":     return 7
        case "Upper":     return 8
        case "OLetter":   return 9
        case "Numeric":   return 10
        case "ATerm":     return 11
        case "STerm":     return 12
        case "SContinue": return 13
        case "Close":     return 14
        default:
            throw SentenceBreakPropertyParseError.invalidCodepoint(lineNumber: -1, raw: value)
        }
    }
}

public extension Array where Element == SentenceBreakPropertyEntry {
    /// Returns a 0x110000-element array of UInt8 raw values (0–14).
    /// Default fill is 0 (Other) per the UCD `@missing` directive.
    func expandSentenceBreak() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = try SentenceBreakCode.rawValue(for: entry.value)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter SentenceBreakCodeTests 2>&1 | tail -10
swift test --filter ExpandSentenceBreakTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 2 + 5 = 7 new tests pass (plus the 8 from Task 1); full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add SentenceBreakCode and expandSentenceBreak

SentenceBreakCode.rawValue(for:) maps all 15 SB values (Other plus the
14 explicit UCD values) to UInt8 raw values 0–14, matching the
UnicodeProperties.SentenceBreak enum layout. expandSentenceBreak()
default-fills with 0 (Other) per the UCD @missing directive and writes
each entry's value across its inclusive codepoint range. Unknown values
propagate a structured parse error.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Codegen run

**Files:**
- Create: `Sources/UnicodeProperties/Generated/SentenceBreakTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated file**

Create `Sources/UnicodeProperties/Generated/SentenceBreakTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let sentenceBreakTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

Verify build:
```bash
swift build 2>&1 | tail -3
```
Expected: build succeeds (placeholder references `TwoStageTrie<UInt8>`, already in scope).

- [ ] **Step 2: Extend main.swift**

Read `Sources/bedrock-ucd-gen/main.swift` first to confirm the current end of file. After the final `emitUInt8` call (the current last statement), append:

```swift
print("---")
print("Parsing SentenceBreakProperty.txt ...")
let sbpPath = "Sources/UnicodeProperties/UCD/SentenceBreakProperty.txt"
let sbpText: String
do {
    sbpText = try String(contentsOfFile: sbpPath, encoding: .utf8)
} catch {
    print("Failed to read \(sbpPath): \(error)")
    exit(1)
}
let sbpEntries: [SentenceBreakPropertyEntry]
do {
    sbpEntries = try SentenceBreakPropertyParser.parse(sbpText)
    print("Parsed \(sbpEntries.count) SentenceBreakProperty entries.")
} catch {
    print("SentenceBreakProperty parse error: \(error)")
    exit(1)
}
let sbpUncompacted: [UInt8]
do {
    sbpUncompacted = try sbpEntries.expandSentenceBreak()
} catch {
    print("SentenceBreak expansion error: \(error)")
    exit(1)
}

print("---")
print("Processing: Sentence_Break")
emitUInt8("Sources/UnicodeProperties/Generated/SentenceBreakTable.swift",
           "sentenceBreakTable", "Sentence_Break", sbpUncompacted)
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -15
```
Expected output includes:
```
---
Parsing SentenceBreakProperty.txt ...
Parsed <N> SentenceBreakProperty entries.
---
Processing: Sentence_Break
Built two-stage trie: stage1=4352 entries, stage2=... entries (... unique blocks).
Self-check OK: 1114112 codepoints round-trip.
Wrote Sources/UnicodeProperties/Generated/SentenceBreakTable.swift (... bytes).
```
Estimated unique blocks: ~40–60 (Upper/Lower span large continuous ranges; most CJK is Other).

If self-check fails — STOP and report. Do not proceed.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite green (no public API references the new table yet, so test count unchanged).

- [ ] **Step 5: Spot-check generated file**

```bash
wc -c Sources/UnicodeProperties/Generated/SentenceBreakTable.swift
head -5 Sources/UnicodeProperties/Generated/SentenceBreakTable.swift
```
Expected: starts with `// GENERATED` banner; size roughly 35–55 KB.

- [ ] **Step 6: Verify other tables unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: ONLY `SentenceBreakTable.swift` shows changes (placeholder → real). If any other file shows a diff, STOP and report.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit SentenceBreakTable

bedrock-ucd-gen extended with SentenceBreakProperty.txt parse + emit
step. Self-check confirms all 1114112 codepoints round-trip through
the TwoStageTrie<UInt8>. Default fill is 0 (Other) per UCD @missing
directive.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Public API + spot-check tests

**Files:**
- Create: `Sources/UnicodeProperties/SentenceBreak.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/SentenceBreakTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UnicodePropertiesTests/SentenceBreakTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct SentenceBreakTests {

    private func sb(_ scalar: Unicode.Scalar) -> UnicodeProperties.SentenceBreak {
        UnicodeProperties.sentenceBreak(of: scalar)
    }

    @Test
    func crIsCR() {
        // U+000D CARRIAGE RETURN
        #expect(sb(Unicode.Scalar(0x000D)!) == .cr)
    }

    @Test
    func lfIsLF() {
        // U+000A LINE FEED
        #expect(sb(Unicode.Scalar(0x000A)!) == .lf)
    }

    @Test
    func nextLineIsSep() {
        // U+0085 NEXT LINE — only Sep codepoint in low BMP
        #expect(sb(Unicode.Scalar(0x0085)!) == .sep)
    }

    @Test
    func combiningGraveIsExtend() {
        // U+0300 COMBINING GRAVE ACCENT — first of Extend range 0300..036F
        #expect(sb(Unicode.Scalar(0x0300)!) == .extend)
    }

    @Test
    func softHyphenIsFormat() {
        // U+00AD SOFT HYPHEN — single-codepoint Format entry
        #expect(sb(Unicode.Scalar(0x00AD)!) == .format)
    }

    @Test
    func spaceIsSp() {
        // U+0020 SPACE
        #expect(sb(Unicode.Scalar(0x0020)!) == .sp)
    }

    @Test
    func latinSmallAIsLower() {
        // U+0061 LATIN SMALL LETTER A — first of Lower range 0061..007A
        #expect(sb("a") == .lower)
    }

    @Test
    func latinCapitalAIsUpper() {
        // U+0041 LATIN CAPITAL LETTER A — first of Upper range 0041..005A
        #expect(sb("A") == .upper)
    }

    @Test
    func latinLetterTwoWithStrokeIsOLetter() {
        // U+01BB LATIN LETTER TWO WITH STROKE — single-codepoint OLetter entry
        #expect(sb(Unicode.Scalar(0x01BB)!) == .oLetter)
    }

    @Test
    func digitZeroIsNumeric() {
        // U+0030 DIGIT ZERO — first of Numeric range 0030..0039
        #expect(sb("0") == .numeric)
    }

    @Test
    func fullStopIsATerm() {
        // U+002E FULL STOP — single-codepoint ATerm entry
        #expect(sb(".") == .aTerm)
    }

    @Test
    func questionMarkIsSTerm() {
        // U+003F QUESTION MARK — single-codepoint STerm entry
        #expect(sb("?") == .sTerm)
    }

    @Test
    func commaIsSContinue() {
        // U+002C COMMA — single-codepoint SContinue entry
        #expect(sb(",") == .sContinue)
    }

    @Test
    func rightParenIsClose() {
        // U+0029 RIGHT PARENTHESIS — single-codepoint Close entry
        #expect(sb(Unicode.Scalar(0x0029)!) == .close)
    }

    @Test
    func emojiIsOther() {
        // U+1F600 GRINNING FACE — not listed in SentenceBreakProperty.txt
        #expect(sb(Unicode.Scalar(0x1F600)!) == .other)
    }

    @Test
    func enumHasFifteenCases() {
        #expect(UnicodeProperties.SentenceBreak.allCases.count == 15)
    }

    @Test
    func rawValuesAreInRange() {
        for sb in UnicodeProperties.SentenceBreak.allCases {
            #expect(sb.rawValue <= 14)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter SentenceBreakTests 2>&1 | tail -5
```
Expected: compile error — `UnicodeProperties.SentenceBreak` and `sentenceBreak(of:)` don't exist.

- [ ] **Step 3: Create `SentenceBreak.swift`**

Create `Sources/UnicodeProperties/SentenceBreak.swift`:
```swift
extension UnicodeProperties {

    /// Sentence_Break property (UAX #29). Used by sentence-
    /// segmentation algorithms to find sentence boundaries.
    /// Returns `.other` for codepoints not explicitly listed in
    /// `SentenceBreakProperty.txt` (the UCD default per @missing).
    public enum SentenceBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other     = 0    // XX (default — not in UCD file)
        case cr        = 1    // CR
        case lf        = 2    // LF
        case sep       = 3    // Sep
        case extend    = 4    // Extend
        case format    = 5    // Format
        case sp        = 6    // Sp
        case lower     = 7    // Lower
        case upper     = 8    // Upper
        case oLetter   = 9    // OLetter
        case numeric   = 10   // Numeric
        case aTerm     = 11   // ATerm
        case sTerm     = 12   // STerm
        case sContinue = 13   // SContinue
        case close     = 14   // Close
    }
}
```

- [ ] **Step 4: Add the entry point**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add after the last existing entry point and before any closing brace for the `UnicodeProperties` type:

```swift
    /// O(1) Sentence_Break lookup (UAX #29).
    ///
    /// Returns the per-codepoint SB property value used by sentence-
    /// segmentation algorithms. Returns `.other` for codepoints absent
    /// from `SentenceBreakProperty.txt` (the UCD default per @missing).
    @inlinable
    public static func sentenceBreak(of scalar: Unicode.Scalar) -> SentenceBreak {
        let raw = sentenceBreakTable.lookup(scalar.value)
        return SentenceBreak(rawValue: raw) ?? .other
    }
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter SentenceBreakTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 17 spot-check tests pass; full suite green.

If a spot-check fails, verify the expected codepoint in `Sources/UnicodeProperties/UCD/SentenceBreakProperty.txt` before altering the test. Do NOT weaken a test or alter a generated table.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add sentenceBreak(of:) entry point

UAX #29 Sentence_Break. Fifteen-case enum (other/cr/lf/sep/extend/
format/sp/lower/upper/oLetter/numeric/aTerm/sTerm/sContinue/close)
with UInt8 raw values 0–14. O(1) lookup via TwoStageTrie<UInt8>;
absent codepoints default to .other (raw 0). Spot-checks cover all
15 cases with verified UCD codepoints.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Exhaustive sweep + coverage

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`

- [ ] **Step 1: Extend the exhaustive test**

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add inside the existing per-codepoint loop after the most recent assertion block:
```swift
            let sb = UnicodeProperties.sentenceBreak(of: scalar)
            #expect(sb.rawValue <= 14,
                    "out-of-range SB raw value at U+\(String(cp, radix: 16))")
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: all tests pass (exhaustive loop now asserts `rawValue <= 14` for all ~1.1M valid scalars).

- [ ] **Step 3: Coverage check**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build|Generated' \
  Sources/UnicodeProperties/UnicodeProperties.swift \
  Sources/UnicodeProperties/SentenceBreak.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/SentenceBreakPropertyParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```
Expected: each file ≥ 90% line coverage.

If `SentenceBreakPropertyParser.swift` falls short, identify uncovered branches. The `sbpRange(of:)` inner path (when needle is not found) and all four error-throw arms should be exercised by Task 1's tests. If a branch is still missing, add a targeted test rather than removing the branch.

Note: `expandSentenceBreak()` throws errors rather than calling `precondition(_:_:)` with messages, so no autoclosure coverage issue arises. This is consistent with the project-level memory note about precondition messages hurting per-file coverage.

- [ ] **Step 4: Commit**

```bash
git add Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
test(unicode-properties): exhaustive sweep for sentenceBreak

ExhaustiveTests now exercises sentenceBreak(of:) across all ~1.1M
valid Unicode scalars and asserts raw value ≤ 14. Full suite passes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** every spec item — `SentenceBreakPropertyEntry`, `SentenceBreakPropertyParseError`, `SentenceBreakPropertyParser`, `SentenceBreakCode`, `expandSentenceBreak`, generated table, `UnicodeProperties.SentenceBreak` enum (15 cases), `sentenceBreak(of:)` entry point — has a task and tests. All 15 spot-check cases from the spec edge-case table are in `SentenceBreakTests.swift`.
- **No placeholders:** every step shows runnable code or an exact command with expected output.
- **Default fill is 0, not something else:** `expandSentenceBreak()` pre-fills with `0` (Other) matching the UCD `@missing: 0000..10FFFF; Other` directive. The `emptyEntriesYieldsAllOther` test explicitly checks `allSatisfy { $0 == 0 }`.
- **Trim helper is file-local:** the private `sbpTrimmed()` and `sbpRange(of:)` extensions on `String` use the `sbp` prefix to avoid name collisions with `gbpTrimmed`/`gbpRange` in `GraphemeBreakPropertyParser.swift`, `wbpTrimmed`/`wbpRange` in `WordBreakPropertyParser.swift`, `eawTrimmed`/`eawRange` in `EastAsianWidthParser.swift`, and `dcpTrimmed`/`dcpRange` in `DerivedCorePropertyParser.swift`. Same convention as every prior parser.
- **No precondition message strings:** `expandSentenceBreak()` throws errors rather than calling `precondition(_:_:)` with messages, so no autoclosure coverage issue arises. This is consistent with the project-level memory note about precondition messages hurting per-file coverage.
- **Codepoint verification:** all test codepoints were verified against the actual vendored `SentenceBreakProperty.txt`:
  - CR = 0x000D (single-codepoint line), LF = 0x000A (single-codepoint line).
  - Sep: 0x0085 NEXT LINE (single-codepoint entry `0085 ; Sep`).
  - Extend: 0x0300 COMBINING GRAVE ACCENT (first of range `0300..036F`).
  - Format: 0x00AD SOFT HYPHEN (single-codepoint entry `00AD ; Format`).
  - Sp: 0x0020 SPACE (single-codepoint entry `0020 ; Sp`).
  - Lower: 0x0061 LATIN SMALL LETTER A (first of range `0061..007A`).
  - Upper: 0x0041 LATIN CAPITAL LETTER A (first of range `0041..005A`).
  - OLetter: 0x01BB LATIN LETTER TWO WITH STROKE (single-codepoint entry `01BB ; OLetter`).
  - Numeric: 0x0030 DIGIT ZERO (first of range `0030..0039`).
  - ATerm: 0x002E FULL STOP (single-codepoint entry `002E ; ATerm`).
  - STerm: 0x003F QUESTION MARK (single-codepoint entry `003F ; STerm`).
  - SContinue: 0x002C COMMA (single-codepoint entry `002C ; SContinue`).
  - Close: 0x0029 RIGHT PARENTHESIS (single-codepoint entry `0029 ; Close`).
  - Other: 0x1F600 GRINNING FACE (not listed anywhere in file).
- **Single table, one new file per layer convention:** `SentenceBreak` is a single-value-per-codepoint property. The codegen step adds exactly one new emission.
- **Parallel worktree safety:** this plan runs alongside Layer 2.11 (WordBreakProperty) in a separate worktree. Both plans append to `main.swift`, `UnicodeProperties.swift`, and `ExhaustiveTests.swift`. Merge conflicts in those three files are simple ordered-append conflicts the controller resolves. No other shared files are touched.
- **Layer doc update omitted:** as instructed, the layer doc update is a final-merge step handled by the controller, not this sub-agent.

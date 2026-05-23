# Word Break Property Implementation Plan (Layer 2.11)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.wordBreak(of:)` per the spec at `docs/superpowers/specs/2026-05-23-word-break-property-design.md`. Introduce a new parser (`WordBreakPropertyParser`) and a new generated table (`WordBreakTable.swift`).

**Architecture:** Single-property parser yields `[WordBreakPropertyEntry]`. An expansion helper produces `[UInt8]` (values 0–18, default 0 = Other). The existing generic `TwoStageTrieBuilder.build` and `CodeEmitter.emit` produce a new `TwoStageTrie<UInt8>` table. One new `@inlinable` entry point. Nineteen-case `UnicodeProperties.WordBreak` enum with `UInt8` raw values.

**Branch:** `layer-2.11-word-break`. Commit each task; controller merges.

**Worktree:** `/Users/satishbabariya/Desktop/Bedrock/.worktrees/layer-2.11`

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/bedrock-ucd-gen/main.swift` — append parse + emit step for WordBreak at the end.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add `wordBreak(of:)` entry point after `graphemeClusterBreak(of:)`.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — sweep the new entry point.

**Creations:**
- `Sources/BedrockUcdGen/WordBreakPropertyParser.swift`
- `Sources/UnicodeProperties/WordBreak.swift`
- `Sources/UnicodeProperties/Generated/WordBreakTable.swift` (placeholder, then real)
- `Tests/BedrockUcdGenTests/WordBreakPropertyParserTests.swift`
- `Tests/BedrockUcdGenTests/ExpandWordBreakTests.swift`
- `Tests/UnicodePropertiesTests/WordBreakTests.swift`

The vendored `Sources/UnicodeProperties/UCD/WordBreakProperty.txt` is already committed.

---

## Task 1: `WordBreakPropertyParser`

**Files:**
- Create: `Sources/BedrockUcdGen/WordBreakPropertyParser.swift`
- Create: `Tests/BedrockUcdGenTests/WordBreakPropertyParserTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/WordBreakPropertyParserTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct WordBreakPropertyParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "000D          ; CR # Cc       <control-000D>\n"
        let entries = try WordBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x000D)
        #expect(entries[0].last  == 0x000D)
        #expect(entries[0].value == "CR")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "0041..005A    ; ALetter # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z\n"
        let entries = try WordBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0041)
        #expect(entries[0].last  == 0x005A)
        #expect(entries[0].value == "ALetter")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # WordBreakProperty-16.0.0.txt
        # @missing: 0000..10FFFF; Other

        000D          ; CR # Cc       <control-000D>

        000A          ; LF # Cc       <control-000A>
        """
        let entries = try WordBreakPropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].value == "CR")
        #expect(entries[1].value == "LF")
    }

    @Test
    func parsesRealisticSnippet() throws {
        let input = """
        000B..000C    ; Newline # Cc   [2] <control-000B>..<control-000C>
        000A          ; LF # Cc       <control-000A>
        000D          ; CR # Cc       <control-000D>
        0022          ; Double_Quote # Po       QUOTATION MARK
        0027          ; Single_Quote # Po       APOSTROPHE
        1F1E6..1F1FF  ; Regional_Indicator # So  [26] REGIONAL INDICATOR SYMBOL LETTER A..Z
        """
        let entries = try WordBreakPropertyParser.parse(input)
        #expect(entries.count == 6)
        #expect(entries[0].value == "Newline")
        #expect(entries[0].first == 0x000B)
        #expect(entries[0].last  == 0x000C)
        #expect(entries[1].value == "LF")
        #expect(entries[2].value == "CR")
        #expect(entries[3].value == "Double_Quote")
        #expect(entries[3].first == 0x0022)
        #expect(entries[3].last  == 0x0022)
        #expect(entries[4].value == "Single_Quote")
        #expect(entries[5].value == "Regional_Indicator")
        #expect(entries[5].first == 0x1F1E6)
        #expect(entries[5].last  == 0x1F1FF)
    }

    @Test
    func rejectsTruncatedLine() {
        // No semicolon — only one field.
        let input = "000D\n"
        do {
            _ = try WordBreakPropertyParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX          ; CR # comment\n"
        do {
            _ = try WordBreakPropertyParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidRange() {
        // Empty second half of range.
        let input = "0041..        ; ALetter # comment\n"
        do {
            _ = try WordBreakPropertyParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyValue() {
        let input = "000D          ; # Cc comment\n"
        do {
            _ = try WordBreakPropertyParser.parse(input)
            Issue.record("expected throw for empty property value")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter WordBreakPropertyParserTests 2>&1 | tail -10
```
Expected: compile error — `WordBreakPropertyParser`, `WordBreakPropertyEntry` don't exist.

- [ ] **Step 3: Implement the parser**

Create `Sources/BedrockUcdGen/WordBreakPropertyParser.swift`:
```swift
public struct WordBreakPropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "CR", "LF", "Newline", "Extend", "ZWJ",
                                // "Regional_Indicator", "Format", "Katakana",
                                // "Hebrew_Letter", "ALetter", "Single_Quote",
                                // "Double_Quote", "MidNumLet", "MidLetter",
                                // "MidNum", "Numeric", "ExtendNumLet", "WSegSpace"

    public init(first: UInt32, last: UInt32, value: String) {
        self.first = first
        self.last  = last
        self.value = value
    }
}

public enum WordBreakPropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum WordBreakPropertyParser {

    public static func parse(_ text: String) throws -> [WordBreakPropertyEntry] {
        var entries: [WordBreakPropertyEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.wbpTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw WordBreakPropertyParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).wbpTrimmed()
            let valueField = String(fields[1]).wbpTrimmed()

            if valueField.isEmpty {
                throw WordBreakPropertyParseError.emptyPropertyValue(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.wbpRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).wbpTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).wbpTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr,  radix: 16) else {
                    throw WordBreakPropertyParseError.invalidRange(lineNumber: lineNumber,
                                                                   raw: rangeField)
                }
                first = f
                last  = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw WordBreakPropertyParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                       raw: rangeField)
                }
                first = cp
                last  = cp
            }

            entries.append(WordBreakPropertyEntry(first: first, last: last, value: valueField))
        }
        return entries
    }
}

private extension String {
    func wbpTrimmed() -> String {
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
    func wbpRange(of needle: String) -> Range<String.Index>? {
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
swift test --filter WordBreakPropertyParserTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 8 parser tests pass; full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add WordBreakPropertyParser

Parses WordBreakProperty.txt UCD format (codepoint-or-range ;
WB-value # comment). Supports all 18 explicit values (CR, LF,
Newline, Extend, ZWJ, Regional_Indicator, Format, Katakana,
Hebrew_Letter, ALetter, Single_Quote, Double_Quote, MidNumLet,
MidLetter, MidNum, Numeric, ExtendNumLet, WSegSpace). Structured
errors for malformed inputs. Stdlib-only whitespace/range helpers
prefixed wbp to avoid collision with existing gbp/eaw/dcp helpers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `WordBreakCode` + expansion helper

**Files:**
- Modify: `Sources/BedrockUcdGen/WordBreakPropertyParser.swift` (append after the parser enum, before the private String extension)
- Create: `Tests/BedrockUcdGenTests/ExpandWordBreakTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/ExpandWordBreakTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct WordBreakCodeTests {

    @Test
    func allNineteenValuesMapCorrectly() throws {
        #expect(try WordBreakCode.rawValue(for: "Other")              == 0)
        #expect(try WordBreakCode.rawValue(for: "CR")                 == 1)
        #expect(try WordBreakCode.rawValue(for: "LF")                 == 2)
        #expect(try WordBreakCode.rawValue(for: "Newline")            == 3)
        #expect(try WordBreakCode.rawValue(for: "Extend")             == 4)
        #expect(try WordBreakCode.rawValue(for: "ZWJ")                == 5)
        #expect(try WordBreakCode.rawValue(for: "Regional_Indicator") == 6)
        #expect(try WordBreakCode.rawValue(for: "Format")             == 7)
        #expect(try WordBreakCode.rawValue(for: "Katakana")           == 8)
        #expect(try WordBreakCode.rawValue(for: "Hebrew_Letter")      == 9)
        #expect(try WordBreakCode.rawValue(for: "ALetter")            == 10)
        #expect(try WordBreakCode.rawValue(for: "Single_Quote")       == 11)
        #expect(try WordBreakCode.rawValue(for: "Double_Quote")       == 12)
        #expect(try WordBreakCode.rawValue(for: "MidNumLet")          == 13)
        #expect(try WordBreakCode.rawValue(for: "MidLetter")          == 14)
        #expect(try WordBreakCode.rawValue(for: "MidNum")             == 15)
        #expect(try WordBreakCode.rawValue(for: "Numeric")            == 16)
        #expect(try WordBreakCode.rawValue(for: "ExtendNumLet")       == 17)
        #expect(try WordBreakCode.rawValue(for: "WSegSpace")          == 18)
    }

    @Test
    func unknownValueThrows() {
        do {
            _ = try WordBreakCode.rawValue(for: "XX")
            Issue.record("expected throw for unknown WB value")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandWordBreakTests {

    @Test
    func emptyEntriesYieldsAllOther() throws {
        let entries: [WordBreakPropertyEntry] = []
        let out = try entries.expandWordBreak()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })   // 0 = Other (default)
    }

    @Test
    func singleCREntryFillsOneCodepoint() throws {
        let entries: [WordBreakPropertyEntry] = [
            WordBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
        ]
        let out = try entries.expandWordBreak()
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x000C] == 0)   // untouched = Other
        #expect(out[0x000E] == 0)
    }

    @Test
    func rangeALetterEntryFillsInclusiveRange() throws {
        let entries: [WordBreakPropertyEntry] = [
            WordBreakPropertyEntry(first: 0x0041, last: 0x005A, value: "ALetter"),
        ]
        let out = try entries.expandWordBreak()
        #expect(out[0x0040] == 0)   // before range = Other
        #expect(out[0x0041] == 10)  // ALetter = 10
        #expect(out[0x005A] == 10)
        #expect(out[0x005B] == 0)   // after range = Other
    }

    @Test
    func multipleEntriesWithDifferentValues() throws {
        let entries: [WordBreakPropertyEntry] = [
            WordBreakPropertyEntry(first: 0x000A, last: 0x000A, value: "LF"),
            WordBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
            WordBreakPropertyEntry(first: 0x0022, last: 0x0022, value: "Double_Quote"),
            WordBreakPropertyEntry(first: 0x0027, last: 0x0027, value: "Single_Quote"),
            WordBreakPropertyEntry(first: 0x0030, last: 0x0039, value: "Numeric"),
            WordBreakPropertyEntry(first: 0x005F, last: 0x005F, value: "ExtendNumLet"),
        ]
        let out = try entries.expandWordBreak()
        #expect(out[0x000A] == 2)   // LF = 2
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x0022] == 12)  // Double_Quote = 12
        #expect(out[0x0027] == 11)  // Single_Quote = 11
        #expect(out[0x0030] == 16)  // Numeric = 16
        #expect(out[0x0039] == 16)  // Numeric = 16
        #expect(out[0x005F] == 17)  // ExtendNumLet = 17
    }

    @Test
    func unknownValueInEntryThrows() {
        let entries: [WordBreakPropertyEntry] = [
            WordBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "XX"),
        ]
        do {
            _ = try entries.expandWordBreak()
            Issue.record("expected throw for unknown WB value")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter WordBreakCodeTests 2>&1 | tail -10
swift test --filter ExpandWordBreakTests 2>&1 | tail -10
```
Expected: compile errors — `WordBreakCode` and `expandWordBreak` don't exist.

- [ ] **Step 3: Implement the code mapper and expansion helper**

In `Sources/BedrockUcdGen/WordBreakPropertyParser.swift`, append AFTER the `WordBreakPropertyParser` enum and BEFORE the private `String` extension:

```swift
public enum WordBreakCode {
    /// Map UCD Word_Break value to UInt8 raw value matching
    /// UnicodeProperties.WordBreak.
    public static func rawValue(for value: String) throws -> UInt8 {
        switch value {
        case "Other":              return 0
        case "CR":                 return 1
        case "LF":                 return 2
        case "Newline":            return 3
        case "Extend":             return 4
        case "ZWJ":                return 5
        case "Regional_Indicator": return 6
        case "Format":             return 7
        case "Katakana":           return 8
        case "Hebrew_Letter":      return 9
        case "ALetter":            return 10
        case "Single_Quote":       return 11
        case "Double_Quote":       return 12
        case "MidNumLet":          return 13
        case "MidLetter":          return 14
        case "MidNum":             return 15
        case "Numeric":            return 16
        case "ExtendNumLet":       return 17
        case "WSegSpace":          return 18
        default:
            throw WordBreakPropertyParseError.invalidCodepoint(lineNumber: -1, raw: value)
        }
    }
}

public extension Array where Element == WordBreakPropertyEntry {
    /// Returns a 0x110000-element array of UInt8 raw values (0–18).
    /// Default fill is 0 (Other) per the UCD `@missing` directive.
    func expandWordBreak() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = try WordBreakCode.rawValue(for: entry.value)
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
swift test --filter WordBreakCodeTests 2>&1 | tail -10
swift test --filter ExpandWordBreakTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 2 + 5 = 7 new tests pass (plus the 8 from Task 1); full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add WordBreakCode and expandWordBreak

WordBreakCode.rawValue(for:) maps all 19 WB values (Other plus the
18 explicit UCD values) to UInt8 raw values 0–18, matching the
UnicodeProperties.WordBreak enum layout.
expandWordBreak() default-fills with 0 (Other) per the UCD @missing
directive and writes each entry's value across its inclusive codepoint
range. Unknown values propagate a structured parse error.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Codegen run

**Files:**
- Create: `Sources/UnicodeProperties/Generated/WordBreakTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated file**

Create `Sources/UnicodeProperties/Generated/WordBreakTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let wordBreakTable = TwoStageTrie<UInt8>(
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
print("Parsing WordBreakProperty.txt ...")
let wbpPath = "Sources/UnicodeProperties/UCD/WordBreakProperty.txt"
let wbpText: String
do {
    wbpText = try String(contentsOfFile: wbpPath, encoding: .utf8)
} catch {
    print("Failed to read \(wbpPath): \(error)")
    exit(1)
}
let wbpEntries: [WordBreakPropertyEntry]
do {
    wbpEntries = try WordBreakPropertyParser.parse(wbpText)
    print("Parsed \(wbpEntries.count) WordBreakProperty entries.")
} catch {
    print("WordBreakProperty parse error: \(error)")
    exit(1)
}
let wbpUncompacted: [UInt8]
do {
    wbpUncompacted = try wbpEntries.expandWordBreak()
} catch {
    print("WordBreak expansion error: \(error)")
    exit(1)
}

print("---")
print("Processing: Word_Break")
emitUInt8("Sources/UnicodeProperties/Generated/WordBreakTable.swift",
           "wordBreakTable", "Word_Break", wbpUncompacted)
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -15
```
Expected output includes:
```
---
Parsing WordBreakProperty.txt ...
Parsed <N> WordBreakProperty entries.
---
Processing: Word_Break
Built two-stage trie: stage1=4352 entries, stage2=... entries (... unique blocks).
Self-check OK: 1114112 codepoints round-trip.
Wrote Sources/UnicodeProperties/Generated/WordBreakTable.swift (... bytes).
```
Estimated unique blocks: ~30–50 (18 distinct values + Other; large uniform ranges for ALetter/Numeric; most SMP is Other).

If self-check fails — STOP and report. Do not proceed.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite green (no public API references the new table yet, so test count unchanged).

- [ ] **Step 5: Spot-check generated file**

```bash
wc -c Sources/UnicodeProperties/Generated/WordBreakTable.swift
head -5 Sources/UnicodeProperties/Generated/WordBreakTable.swift
```
Expected: starts with `// GENERATED` banner; size roughly 25–45 KB.

- [ ] **Step 6: Verify other tables unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: ONLY `WordBreakTable.swift` shows changes (placeholder → real). If any other file shows a diff, STOP and report.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit WordBreakTable

bedrock-ucd-gen extended with WordBreakProperty.txt parse + emit step.
Self-check confirms all 1114112 codepoints round-trip through the
TwoStageTrie<UInt8>. Default fill is 0 (Other) per UCD @missing
directive.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Public API + spot-check tests

**Files:**
- Create: `Sources/UnicodeProperties/WordBreak.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/WordBreakTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UnicodePropertiesTests/WordBreakTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct WordBreakTests {

    private func wb(_ scalar: Unicode.Scalar) -> UnicodeProperties.WordBreak {
        UnicodeProperties.wordBreak(of: scalar)
    }

    @Test
    func crIsCR() {
        // U+000D CARRIAGE RETURN
        #expect(wb(Unicode.Scalar(0x000D)!) == .cr)
    }

    @Test
    func lfIsLF() {
        // U+000A LINE FEED
        #expect(wb(Unicode.Scalar(0x000A)!) == .lf)
    }

    @Test
    func verticalTabIsNewline() {
        // U+000B <control-000B> — in Newline range 000B..000C
        #expect(wb(Unicode.Scalar(0x000B)!) == .newline)
    }

    @Test
    func nelIsNewline() {
        // U+0085 NEXT LINE (NEL)
        #expect(wb(Unicode.Scalar(0x0085)!) == .newline)
    }

    @Test
    func combiningGraveIsExtend() {
        // U+0300 COMBINING GRAVE ACCENT — first of Extend range 0300..036F
        #expect(wb(Unicode.Scalar(0x0300)!) == .extend)
    }

    @Test
    func zwjIsZWJ() {
        // U+200D ZERO WIDTH JOINER
        #expect(wb(Unicode.Scalar(0x200D)!) == .zwj)
    }

    @Test
    func regionalIndicatorAIsRegionalIndicator() {
        // U+1F1E6 REGIONAL INDICATOR SYMBOL LETTER A
        #expect(wb(Unicode.Scalar(0x1F1E6)!) == .regionalIndicator)
    }

    @Test
    func softHyphenIsFormat() {
        // U+00AD SOFT HYPHEN — listed as Format
        #expect(wb(Unicode.Scalar(0x00AD)!) == .format)
    }

    @Test
    func katakanaHiraganaDoubleHyphenIsKatakana() {
        // U+30A0 KATAKANA-HIRAGANA DOUBLE HYPHEN
        #expect(wb(Unicode.Scalar(0x30A0)!) == .katakana)
    }

    @Test
    func hebrewAlefIsHebrewLetter() {
        // U+05D0 HEBREW LETTER ALEF — first of Hebrew_Letter range 05D0..05EA
        #expect(wb(Unicode.Scalar(0x05D0)!) == .hebrewLetter)
    }

    @Test
    func latinCapitalAIsALetter() {
        // U+0041 LATIN CAPITAL LETTER A — first of ALetter range 0041..005A
        #expect(wb("A") == .aLetter)
    }

    @Test
    func apostropheIsSingleQuote() {
        // U+0027 APOSTROPHE
        #expect(wb(Unicode.Scalar(0x0027)!) == .singleQuote)
    }

    @Test
    func quotationMarkIsDoubleQuote() {
        // U+0022 QUOTATION MARK
        #expect(wb(Unicode.Scalar(0x0022)!) == .doubleQuote)
    }

    @Test
    func fullStopIsMidNumLet() {
        // U+002E FULL STOP
        #expect(wb(Unicode.Scalar(0x002E)!) == .midNumLet)
    }

    @Test
    func colonIsMidLetter() {
        // U+003A COLON
        #expect(wb(Unicode.Scalar(0x003A)!) == .midLetter)
    }

    @Test
    func commaIsMidNum() {
        // U+002C COMMA
        #expect(wb(Unicode.Scalar(0x002C)!) == .midNum)
    }

    @Test
    func digitZeroIsNumeric() {
        // U+0030 DIGIT ZERO — first of Numeric range 0030..0039
        #expect(wb(Unicode.Scalar(0x0030)!) == .numeric)
    }

    @Test
    func lowLineIsExtendNumLet() {
        // U+005F LOW LINE (underscore)
        #expect(wb(Unicode.Scalar(0x005F)!) == .extendNumLet)
    }

    @Test
    func spaceIsWSegSpace() {
        // U+0020 SPACE
        #expect(wb(Unicode.Scalar(0x0020)!) == .wSegSpace)
    }

    @Test
    func cjkUnifiedIdeographIsOther() {
        // U+4E00 CJK UNIFIED IDEOGRAPH-4E00 — not in WordBreakProperty.txt
        #expect(wb(Unicode.Scalar(0x4E00)!) == .other)
    }

    @Test
    func enumHasNineteenCases() {
        #expect(UnicodeProperties.WordBreak.allCases.count == 19)
    }

    @Test
    func rawValuesAreInRange() {
        for wb in UnicodeProperties.WordBreak.allCases {
            #expect(wb.rawValue <= 18)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter WordBreakTests 2>&1 | tail -5
```
Expected: compile error — `UnicodeProperties.WordBreak` and `wordBreak(of:)` don't exist.

- [ ] **Step 3: Create `WordBreak.swift`**

Create `Sources/UnicodeProperties/WordBreak.swift`:
```swift
extension UnicodeProperties {

    /// Word_Break property (UAX #29). Used by word-segmentation
    /// algorithms to find word boundaries. Returns `.other` for
    /// codepoints not explicitly listed in `WordBreakProperty.txt`
    /// (the UCD default per @missing).
    public enum WordBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other             = 0   // XX (default — not in UCD file)
        case cr                = 1   // CR
        case lf                = 2   // LF
        case newline           = 3   // Newline
        case extend            = 4   // Extend
        case zwj               = 5   // ZWJ
        case regionalIndicator = 6   // Regional_Indicator
        case format            = 7   // Format
        case katakana          = 8   // Katakana
        case hebrewLetter      = 9   // Hebrew_Letter
        case aLetter           = 10  // ALetter
        case singleQuote       = 11  // Single_Quote
        case doubleQuote       = 12  // Double_Quote
        case midNumLet         = 13  // MidNumLet
        case midLetter         = 14  // MidLetter
        case midNum            = 15  // MidNum
        case numeric           = 16  // Numeric
        case extendNumLet      = 17  // ExtendNumLet
        case wSegSpace         = 18  // WSegSpace
    }
}
```

- [ ] **Step 4: Add the entry point**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add after `graphemeClusterBreak(of:)` (or after `eastAsianWidth(of:)` if Layer 2.10 has not yet merged):

```swift
    /// O(1) Word_Break lookup (UAX #29).
    ///
    /// Returns the per-codepoint WB property value used by word-
    /// segmentation algorithms. Returns `.other` for codepoints absent
    /// from `WordBreakProperty.txt` (the UCD default per @missing).
    @inlinable
    public static func wordBreak(of scalar: Unicode.Scalar) -> WordBreak {
        let raw = wordBreakTable.lookup(scalar.value)
        return WordBreak(rawValue: raw) ?? .other
    }
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter WordBreakTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 22 spot-check tests pass; full suite green.

If a spot-check fails, verify the expected codepoint in `Sources/UnicodeProperties/UCD/WordBreakProperty.txt` before altering the test. Do NOT weaken a test or alter a generated table.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add wordBreak(of:) entry point

UAX #29 Word_Break. Nineteen-case enum (other/cr/lf/newline/extend/
zwj/regionalIndicator/format/katakana/hebrewLetter/aLetter/
singleQuote/doubleQuote/midNumLet/midLetter/midNum/numeric/
extendNumLet/wSegSpace) with UInt8 raw values 0–18. O(1) lookup via
TwoStageTrie<UInt8>; absent codepoints default to .other (raw 0).
Spot-checks cover all 19 cases with verified UCD codepoints.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Exhaustive sweep + coverage

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`

- [ ] **Step 1: Extend the exhaustive test**

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add inside the existing per-codepoint loop after the most recent assertion block (e.g., after `gcb`):
```swift
            let wb = UnicodeProperties.wordBreak(of: scalar)
            #expect(wb.rawValue <= 18,
                    "out-of-range WB raw value at U+\(String(cp, radix: 16))")
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: all tests pass (exhaustive loop now asserts `rawValue <= 18` for all ~1.1M valid scalars).

- [ ] **Step 3: Coverage check**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build|Generated' \
  Sources/UnicodeProperties/UnicodeProperties.swift \
  Sources/UnicodeProperties/WordBreak.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/WordBreakPropertyParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```
Expected: each file ≥ 90% line coverage.

If `WordBreakPropertyParser.swift` falls short, identify uncovered branches. The `wbpRange(of:)` inner path (when needle is not found) and all four error-throw arms should be exercised by Task 1's tests. If a branch is still missing, add a targeted test rather than removing the branch.

Note: `expandWordBreak()` throws errors rather than calling `precondition(_:_:)` with messages, so no autoclosure coverage issue arises. This is consistent with the project-level memory note about precondition messages hurting coverage.

- [ ] **Step 4: Commit**

```bash
git add Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
test(unicode-properties): exhaustive sweep for wordBreak

ExhaustiveTests now exercises wordBreak(of:) across all ~1.1M valid
Unicode scalars and asserts raw value <= 18. Full suite passes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** every spec item — `WordBreakPropertyEntry`, `WordBreakPropertyParseError`, `WordBreakPropertyParser`, `WordBreakCode`, `expandWordBreak`, generated table, `UnicodeProperties.WordBreak` enum (19 cases), `wordBreak(of:)` entry point — has a task and tests. All 19 spot-check cases (one per enum value) are in `WordBreakTests.swift`.
- **No placeholders:** every step shows runnable code or an exact command with expected output.
- **Default fill is 0, not 5:** `expandWordBreak()` pre-fills with `0` (Other) matching the UCD `@missing: 0000..10FFFF; Other` directive. The `emptyEntriesYieldsAllOther` test explicitly checks `allSatisfy { $0 == 0 }`. (Contrast with EAW which uses 5 = Neutral as default.)
- **Trim helper is file-local:** the private `wbpTrimmed()` and `wbpRange(of:)` extensions on `String` use the `wbp` prefix to avoid name collisions with `gbpTrimmed`/`gbpRange` in `GraphemeBreakPropertyParser.swift`, `eawTrimmed`/`eawRange` in `EastAsianWidthParser.swift`, and `dcpTrimmed`/`dcpRange` in `DerivedCorePropertyParser.swift`. Same convention as every prior parser.
- **No precondition message strings:** `expandWordBreak()` throws errors rather than calling `precondition(_:_:)` with messages, so no autoclosure coverage issue arises. This is consistent with the project-level memory note about precondition messages hurting per-file coverage.
- **Codepoint verification:** all test codepoints were verified against the actual vendored `WordBreakProperty.txt`:
  - CR = 0x000D (single-codepoint line), LF = 0x000A.
  - Newline: 0x000B (first of range `000B..000C`), 0x0085 (single-codepoint entry).
  - Extend: 0x0300 (first of range `0300..036F`).
  - ZWJ: 0x200D (single-codepoint entry).
  - Regional_Indicator: 0x1F1E6 (first of range `1F1E6..1F1FF`).
  - Format: 0x00AD SOFT HYPHEN (listed in Format entries).
  - Katakana: 0x30A0 KATAKANA-HIRAGANA DOUBLE HYPHEN (single-codepoint entry).
  - Hebrew_Letter: 0x05D0 (first of range `05D0..05EA`).
  - ALetter: 0x0041 (first of range `0041..005A`).
  - Single_Quote: 0x0027 (single-codepoint entry).
  - Double_Quote: 0x0022 (single-codepoint entry).
  - MidNumLet: 0x002E FULL STOP (single-codepoint entry).
  - MidLetter: 0x003A COLON (single-codepoint entry).
  - MidNum: 0x002C COMMA (single-codepoint entry).
  - Numeric: 0x0030 (first of range `0030..0039`).
  - ExtendNumLet: 0x005F LOW LINE (single-codepoint entry).
  - WSegSpace: 0x0020 SPACE (single-codepoint entry).
  - Other: 0x4E00 CJK UNIFIED IDEOGRAPH-4E00 (not listed anywhere in file).
- **Single table, one new file per layer convention:** `WordBreak` is a single-value-per-codepoint property. The codegen step adds exactly one new emission.
- **Entry point placement:** if Layer 2.10 has merged, add `wordBreak(of:)` after `graphemeClusterBreak(of:)`. If Layer 2.10 is still open, add after `eastAsianWidth(of:)`. Either is a simple append; the controller resolves ordering at merge time.
- **Parallel worktree safety:** this plan touches `WordBreakPropertyParser.swift` (new file) and appends to the very end of `main.swift`. Merge conflicts are possible only in `main.swift`, `UnicodeProperties.swift`, and `ExhaustiveTests.swift`; all are simple appends that the controller can resolve by ordering the append blocks.
- **Layer doc update omitted:** as instructed, the layer doc update is a final-merge step handled by the controller, not this sub-agent.

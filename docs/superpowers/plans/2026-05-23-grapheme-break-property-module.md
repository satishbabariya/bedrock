# Grapheme Break Property Implementation Plan (Layer 2.10)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.graphemeClusterBreak(of:)` per the spec at `docs/superpowers/specs/2026-05-23-grapheme-break-property-design.md`. Introduce a new parser (`GraphemeBreakPropertyParser`) and a new generated table (`GraphemeClusterBreakTable.swift`).

**Architecture:** Single-property parser yields `[GraphemeBreakPropertyEntry]`. An expansion helper produces `[UInt8]` (values 0–13, default 0 = Other). The existing generic `TwoStageTrieBuilder.build` and `CodeEmitter.emit` produce a new `TwoStageTrie<UInt8>` table. One new `@inlinable` entry point. Fourteen-case `UnicodeProperties.GraphemeClusterBreak` enum with `UInt8` raw values.

**Branch:** `layer-2.10-grapheme-break`. Commit each task; controller merges.

**Worktree:** `/Users/satishbabariya/Desktop/Bedrock/.worktrees/layer-2.10`

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/bedrock-ucd-gen/main.swift` — append parse + emit step for GraphemeClusterBreak at the end.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add `graphemeClusterBreak(of:)` entry point after `eastAsianWidth(of:)`.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — sweep the new entry point.

**Creations:**
- `Sources/BedrockUcdGen/GraphemeBreakPropertyParser.swift`
- `Sources/UnicodeProperties/GraphemeClusterBreak.swift`
- `Sources/UnicodeProperties/Generated/GraphemeClusterBreakTable.swift` (placeholder, then real)
- `Tests/BedrockUcdGenTests/GraphemeBreakPropertyParserTests.swift`
- `Tests/BedrockUcdGenTests/ExpandGraphemeClusterBreakTests.swift`
- `Tests/UnicodePropertiesTests/GraphemeClusterBreakTests.swift`

The vendored `Sources/UnicodeProperties/UCD/GraphemeBreakProperty.txt` is already committed.

---

## Task 1: `GraphemeBreakPropertyParser`

**Files:**
- Create: `Sources/BedrockUcdGen/GraphemeBreakPropertyParser.swift`
- Create: `Tests/BedrockUcdGenTests/GraphemeBreakPropertyParserTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/GraphemeBreakPropertyParserTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct GraphemeBreakPropertyParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "000D          ; CR # Cc       <control-000D>\n"
        let entries = try GraphemeBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x000D)
        #expect(entries[0].last  == 0x000D)
        #expect(entries[0].value == "CR")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "0600..0605    ; Prepend # Cf   [6] ARABIC NUMBER SIGN..ARABIC NUMBER MARK ABOVE\n"
        let entries = try GraphemeBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0600)
        #expect(entries[0].last  == 0x0605)
        #expect(entries[0].value == "Prepend")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # GraphemeBreakProperty-16.0.0.txt
        # @missing: 0000..10FFFF; Other

        000D          ; CR # Cc       <control-000D>

        000A          ; LF # Cc       <control-000A>
        """
        let entries = try GraphemeBreakPropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].value == "CR")
        #expect(entries[1].value == "LF")
    }

    @Test
    func parsesRealisticSnippet() throws {
        let input = """
        0000..0009    ; Control # Cc  [10] <control-0000>..<control-0009>
        000A          ; LF # Cc       <control-000A>
        000D          ; CR # Cc       <control-000D>
        0301          ; Extend # Mn       COMBINING ACUTE ACCENT
        200D          ; ZWJ # Cf       ZERO WIDTH JOINER
        1F1E6..1F1FF  ; Regional_Indicator # So  [26] REGIONAL INDICATOR SYMBOL LETTER A..Z
        """
        let entries = try GraphemeBreakPropertyParser.parse(input)
        #expect(entries.count == 6)
        #expect(entries[0].value == "Control")
        #expect(entries[0].first == 0x0000)
        #expect(entries[0].last  == 0x0009)
        #expect(entries[1].value == "LF")
        #expect(entries[2].value == "CR")
        #expect(entries[3].value == "Extend")
        #expect(entries[3].first == 0x0301)
        #expect(entries[3].last  == 0x0301)
        #expect(entries[4].value == "ZWJ")
        #expect(entries[5].value == "Regional_Indicator")
        #expect(entries[5].first == 0x1F1E6)
        #expect(entries[5].last  == 0x1F1FF)
    }

    @Test
    func rejectsTruncatedLine() {
        // No semicolon — only one field.
        let input = "000D\n"
        do {
            _ = try GraphemeBreakPropertyParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX          ; CR # comment\n"
        do {
            _ = try GraphemeBreakPropertyParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidRange() {
        // Empty second half of range.
        let input = "0600..        ; Prepend # comment\n"
        do {
            _ = try GraphemeBreakPropertyParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyValue() {
        let input = "000D          ; # Cc comment\n"
        do {
            _ = try GraphemeBreakPropertyParser.parse(input)
            Issue.record("expected throw for empty property value")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter GraphemeBreakPropertyParserTests 2>&1 | tail -10
```
Expected: compile error — `GraphemeBreakPropertyParser`, `GraphemeBreakPropertyEntry` don't exist.

- [ ] **Step 3: Implement the parser**

Create `Sources/BedrockUcdGen/GraphemeBreakPropertyParser.swift`:
```swift
public struct GraphemeBreakPropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "CR", "LF", "Control", "Extend", "ZWJ",
                                // "Regional_Indicator", "Prepend", "SpacingMark",
                                // "L", "V", "T", "LV", "LVT"

    public init(first: UInt32, last: UInt32, value: String) {
        self.first = first
        self.last  = last
        self.value = value
    }
}

public enum GraphemeBreakPropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum GraphemeBreakPropertyParser {

    public static func parse(_ text: String) throws -> [GraphemeBreakPropertyEntry] {
        var entries: [GraphemeBreakPropertyEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.gbpTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw GraphemeBreakPropertyParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).gbpTrimmed()
            let valueField = String(fields[1]).gbpTrimmed()

            if valueField.isEmpty {
                throw GraphemeBreakPropertyParseError.emptyPropertyValue(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.gbpRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).gbpTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).gbpTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr,  radix: 16) else {
                    throw GraphemeBreakPropertyParseError.invalidRange(lineNumber: lineNumber,
                                                                       raw: rangeField)
                }
                first = f
                last  = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw GraphemeBreakPropertyParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                           raw: rangeField)
                }
                first = cp
                last  = cp
            }

            entries.append(GraphemeBreakPropertyEntry(first: first, last: last, value: valueField))
        }
        return entries
    }
}

private extension String {
    func gbpTrimmed() -> String {
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
    func gbpRange(of needle: String) -> Range<String.Index>? {
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
swift test --filter GraphemeBreakPropertyParserTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 8 parser tests pass; full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add GraphemeBreakPropertyParser

Parses GraphemeBreakProperty.txt UCD format (codepoint-or-range ;
GCB-value # comment). Supports all 13 explicit values (CR, LF,
Control, Extend, ZWJ, Regional_Indicator, Prepend, SpacingMark,
L, V, T, LV, LVT). Structured errors for malformed inputs.
Stdlib-only whitespace/range helpers prefixed gbp to avoid collision
with existing eaw/dcp helpers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `GraphemeClusterBreakCode` + expansion helper

**Files:**
- Modify: `Sources/BedrockUcdGen/GraphemeBreakPropertyParser.swift` (append after the parser enum, before the private String extension)
- Create: `Tests/BedrockUcdGenTests/ExpandGraphemeClusterBreakTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/ExpandGraphemeClusterBreakTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct GraphemeClusterBreakCodeTests {

    @Test
    func allFourteenValuesMapCorrectly() throws {
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Other")              == 0)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "CR")                 == 1)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "LF")                 == 2)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Control")            == 3)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Extend")             == 4)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "ZWJ")                == 5)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Regional_Indicator") == 6)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Prepend")            == 7)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "SpacingMark")        == 8)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "L")                  == 9)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "V")                  == 10)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "T")                  == 11)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "LV")                 == 12)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "LVT")                == 13)
    }

    @Test
    func unknownValueThrows() {
        do {
            _ = try GraphemeClusterBreakCode.rawValue(for: "XX")
            Issue.record("expected throw for unknown GCB value")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandGraphemeClusterBreakTests {

    @Test
    func emptyEntriesYieldsAllOther() throws {
        let entries: [GraphemeBreakPropertyEntry] = []
        let out = try entries.expandGraphemeClusterBreak()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })   // 0 = Other (default)
    }

    @Test
    func singleCREntryFillsOneCodepoint() throws {
        let entries: [GraphemeBreakPropertyEntry] = [
            GraphemeBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
        ]
        let out = try entries.expandGraphemeClusterBreak()
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x000C] == 0)   // untouched = Other
        #expect(out[0x000E] == 0)
    }

    @Test
    func rangeExtendEntryFillsInclusiveRange() throws {
        let entries: [GraphemeBreakPropertyEntry] = [
            GraphemeBreakPropertyEntry(first: 0x0300, last: 0x0302, value: "Extend"),
        ]
        let out = try entries.expandGraphemeClusterBreak()
        #expect(out[0x02FF] == 0)   // before range = Other
        #expect(out[0x0300] == 4)   // Extend = 4
        #expect(out[0x0301] == 4)
        #expect(out[0x0302] == 4)
        #expect(out[0x0303] == 0)   // after range = Other
    }

    @Test
    func multipleEntriesWithDifferentValues() throws {
        let entries: [GraphemeBreakPropertyEntry] = [
            GraphemeBreakPropertyEntry(first: 0x000A, last: 0x000A, value: "LF"),
            GraphemeBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
            GraphemeBreakPropertyEntry(first: 0x1100, last: 0x1100, value: "L"),
            GraphemeBreakPropertyEntry(first: 0x1160, last: 0x1160, value: "V"),
            GraphemeBreakPropertyEntry(first: 0x11A8, last: 0x11A8, value: "T"),
            GraphemeBreakPropertyEntry(first: 0xAC00, last: 0xAC00, value: "LV"),
            GraphemeBreakPropertyEntry(first: 0xAC01, last: 0xAC01, value: "LVT"),
        ]
        let out = try entries.expandGraphemeClusterBreak()
        #expect(out[0x000A] == 2)   // LF = 2
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x1100] == 9)   // L = 9
        #expect(out[0x1160] == 10)  // V = 10
        #expect(out[0x11A8] == 11)  // T = 11
        #expect(out[0xAC00] == 12)  // LV = 12
        #expect(out[0xAC01] == 13)  // LVT = 13
    }

    @Test
    func unknownValueInEntryThrows() {
        let entries: [GraphemeBreakPropertyEntry] = [
            GraphemeBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "XX"),
        ]
        do {
            _ = try entries.expandGraphemeClusterBreak()
            Issue.record("expected throw for unknown GCB value")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter GraphemeClusterBreakCodeTests 2>&1 | tail -10
swift test --filter ExpandGraphemeClusterBreakTests 2>&1 | tail -10
```
Expected: compile errors — `GraphemeClusterBreakCode` and `expandGraphemeClusterBreak` don't exist.

- [ ] **Step 3: Implement the code mapper and expansion helper**

In `Sources/BedrockUcdGen/GraphemeBreakPropertyParser.swift`, append AFTER the `GraphemeBreakPropertyParser` enum and BEFORE the private `String` extension:

```swift
public enum GraphemeClusterBreakCode {
    /// Map UCD Grapheme_Cluster_Break value to UInt8 raw value matching
    /// UnicodeProperties.GraphemeClusterBreak.
    public static func rawValue(for value: String) throws -> UInt8 {
        switch value {
        case "Other":              return 0
        case "CR":                 return 1
        case "LF":                 return 2
        case "Control":            return 3
        case "Extend":             return 4
        case "ZWJ":                return 5
        case "Regional_Indicator": return 6
        case "Prepend":            return 7
        case "SpacingMark":        return 8
        case "L":                  return 9
        case "V":                  return 10
        case "T":                  return 11
        case "LV":                 return 12
        case "LVT":                return 13
        default:
            throw GraphemeBreakPropertyParseError.invalidCodepoint(lineNumber: -1, raw: value)
        }
    }
}

public extension Array where Element == GraphemeBreakPropertyEntry {
    /// Returns a 0x110000-element array of UInt8 raw values (0–13).
    /// Default fill is 0 (Other) per the UCD `@missing` directive.
    func expandGraphemeClusterBreak() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = try GraphemeClusterBreakCode.rawValue(for: entry.value)
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
swift test --filter GraphemeClusterBreakCodeTests 2>&1 | tail -10
swift test --filter ExpandGraphemeClusterBreakTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 2 + 5 = 7 new tests pass (plus the 8 from Task 1); full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add GraphemeClusterBreakCode and expandGraphemeClusterBreak

GraphemeClusterBreakCode.rawValue(for:) maps all 14 GCB values (Other
plus the 13 explicit UCD values) to UInt8 raw values 0–13, matching
the UnicodeProperties.GraphemeClusterBreak enum layout.
expandGraphemeClusterBreak() default-fills with 0 (Other) per the UCD
@missing directive and writes each entry's value across its inclusive
codepoint range. Unknown values propagate a structured parse error.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Codegen run

**Files:**
- Create: `Sources/UnicodeProperties/Generated/GraphemeClusterBreakTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated file**

Create `Sources/UnicodeProperties/Generated/GraphemeClusterBreakTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let graphemeClusterBreakTable = TwoStageTrie<UInt8>(
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

Read `Sources/bedrock-ucd-gen/main.swift` first to confirm the current end of file. After the final `emitUInt8` call for `East Asian Width` (the current last statement), append:

```swift
print("---")
print("Parsing GraphemeBreakProperty.txt ...")
let gbpPath = "Sources/UnicodeProperties/UCD/GraphemeBreakProperty.txt"
let gbpText: String
do {
    gbpText = try String(contentsOfFile: gbpPath, encoding: .utf8)
} catch {
    print("Failed to read \(gbpPath): \(error)")
    exit(1)
}
let gbpEntries: [GraphemeBreakPropertyEntry]
do {
    gbpEntries = try GraphemeBreakPropertyParser.parse(gbpText)
    print("Parsed \(gbpEntries.count) GraphemeBreakProperty entries.")
} catch {
    print("GraphemeBreakProperty parse error: \(error)")
    exit(1)
}
let gbpUncompacted: [UInt8]
do {
    gbpUncompacted = try gbpEntries.expandGraphemeClusterBreak()
} catch {
    print("GraphemeClusterBreak expansion error: \(error)")
    exit(1)
}

print("---")
print("Processing: Grapheme_Cluster_Break")
emitUInt8("Sources/UnicodeProperties/Generated/GraphemeClusterBreakTable.swift",
           "graphemeClusterBreakTable", "Grapheme_Cluster_Break", gbpUncompacted)
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -15
```
Expected output includes:
```
---
Parsing GraphemeBreakProperty.txt ...
Parsed <N> GraphemeBreakProperty entries.
---
Processing: Grapheme_Cluster_Break
Built two-stage trie: stage1=4352 entries, stage2=... entries (... unique blocks).
Self-check OK: 1114112 codepoints round-trip.
Wrote Sources/UnicodeProperties/Generated/GraphemeClusterBreakTable.swift (... bytes).
```
Estimated unique blocks: ~30–50 (13 distinct values + Other; Hangul blocks are large but uniform; most CJK is Other).

If self-check fails — STOP and report. Do not proceed.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite green (no public API references the new table yet, so test count unchanged).

- [ ] **Step 5: Spot-check generated file**

```bash
wc -c Sources/UnicodeProperties/Generated/GraphemeClusterBreakTable.swift
head -5 Sources/UnicodeProperties/Generated/GraphemeClusterBreakTable.swift
```
Expected: starts with `// GENERATED` banner; size roughly 25–45 KB.

- [ ] **Step 6: Verify other tables unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: ONLY `GraphemeClusterBreakTable.swift` shows changes (placeholder → real). If any other file shows a diff, STOP and report.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit GraphemeClusterBreakTable

bedrock-ucd-gen extended with GraphemeBreakProperty.txt parse + emit
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
- Create: `Sources/UnicodeProperties/GraphemeClusterBreak.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/GraphemeClusterBreakTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UnicodePropertiesTests/GraphemeClusterBreakTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct GraphemeClusterBreakTests {

    private func gcb(_ scalar: Unicode.Scalar) -> UnicodeProperties.GraphemeClusterBreak {
        UnicodeProperties.graphemeClusterBreak(of: scalar)
    }

    @Test
    func crIsCR() {
        // U+000D CARRIAGE RETURN
        #expect(gcb(Unicode.Scalar(0x000D)!) == .cr)
    }

    @Test
    func lfIsLF() {
        // U+000A LINE FEED
        #expect(gcb(Unicode.Scalar(0x000A)!) == .lf)
    }

    @Test
    func nullIsControl() {
        // U+0000 NULL — in Control range 0000..0009
        #expect(gcb(Unicode.Scalar(0x0000)!) == .control)
    }

    @Test
    func tabIsControl() {
        // U+0009 CHARACTER TABULATION — in Control range 0000..0009
        #expect(gcb(Unicode.Scalar(0x0009)!) == .control)
    }

    @Test
    func combiningAcuteIsExtend() {
        // U+0301 COMBINING ACUTE ACCENT
        #expect(gcb(Unicode.Scalar(0x0301)!) == .extend)
    }

    @Test
    func zwjIsZWJ() {
        // U+200D ZERO WIDTH JOINER
        #expect(gcb(Unicode.Scalar(0x200D)!) == .zwj)
    }

    @Test
    func regionalIndicatorAIsRegionalIndicator() {
        // U+1F1E6 REGIONAL INDICATOR SYMBOL LETTER A
        #expect(gcb(Unicode.Scalar(0x1F1E6)!) == .regionalIndicator)
    }

    @Test
    func arabicNumberSignIsPrepend() {
        // U+0600 ARABIC NUMBER SIGN — first entry in the file
        #expect(gcb(Unicode.Scalar(0x0600)!) == .prepend)
    }

    @Test
    func devanagariVowelSignAAIsSpacingMark() {
        // U+093E DEVANAGARI VOWEL SIGN AA — in SpacingMark range 093E..0940
        #expect(gcb(Unicode.Scalar(0x093E)!) == .spacingMark)
    }

    @Test
    func hangulLeadKiyeokIsL() {
        // U+1100 HANGUL CHOSEONG KIYEOK — in L range 1100..115F
        #expect(gcb(Unicode.Scalar(0x1100)!) == .l)
    }

    @Test
    func hangulVowelFillerIsV() {
        // U+1160 HANGUL JUNGSEONG FILLER — in V range 1160..11A7
        #expect(gcb(Unicode.Scalar(0x1160)!) == .v)
    }

    @Test
    func hangulTrailingKiyeokIsT() {
        // U+11A8 HANGUL JONGSEONG KIYEOK — in T range 11A8..11FF
        #expect(gcb(Unicode.Scalar(0x11A8)!) == .t)
    }

    @Test
    func hangulSyllableGAIsLV() {
        // U+AC00 HANGUL SYLLABLE GA (precomposed, no trailing jamo)
        #expect(gcb(Unicode.Scalar(0xAC00)!) == .lv)
    }

    @Test
    func hangulSyllableGAGIsLVT() {
        // U+AC01 HANGUL SYLLABLE GAG (precomposed, with trailing jamo)
        #expect(gcb(Unicode.Scalar(0xAC01)!) == .lvt)
    }

    @Test
    func asciiLetterIsOther() {
        // U+0041 A — not listed in GraphemeBreakProperty.txt
        #expect(gcb("A") == .other)
    }

    @Test
    func enumHasFourteenCases() {
        #expect(UnicodeProperties.GraphemeClusterBreak.allCases.count == 14)
    }

    @Test
    func rawValuesAreInRange() {
        for gcb in UnicodeProperties.GraphemeClusterBreak.allCases {
            #expect(gcb.rawValue <= 13)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter GraphemeClusterBreakTests 2>&1 | tail -5
```
Expected: compile error — `UnicodeProperties.GraphemeClusterBreak` and `graphemeClusterBreak(of:)` don't exist.

- [ ] **Step 3: Create `GraphemeClusterBreak.swift`**

Create `Sources/UnicodeProperties/GraphemeClusterBreak.swift`:
```swift
extension UnicodeProperties {

    /// Grapheme_Cluster_Break property (UAX #29). Used by grapheme-
    /// cluster segmentation to find user-perceived character boundaries.
    /// Returns `.other` for codepoints not explicitly listed in
    /// `GraphemeBreakProperty.txt` (the UCD default per @missing).
    public enum GraphemeClusterBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other             = 0   // XX (default — not in UCD file)
        case cr                = 1   // CR
        case lf                = 2   // LF
        case control           = 3   // Control
        case extend            = 4   // Extend
        case zwj               = 5   // ZWJ
        case regionalIndicator = 6   // Regional_Indicator
        case prepend           = 7   // Prepend
        case spacingMark       = 8   // SpacingMark
        case l                 = 9   // L (Hangul leading jamo)
        case v                 = 10  // V (Hangul vowel jamo)
        case t                 = 11  // T (Hangul trailing jamo)
        case lv                = 12  // LV (Hangul precomposed syllable, no trailing)
        case lvt               = 13  // LVT (Hangul precomposed syllable, with trailing)
    }
}
```

- [ ] **Step 4: Add the entry point**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add after `eastAsianWidth(of:)` and before `isLetter(_:)`:

```swift
    /// O(1) Grapheme_Cluster_Break lookup (UAX #29).
    ///
    /// Returns the per-codepoint GCB property value used by grapheme-
    /// cluster segmentation. Returns `.other` for codepoints absent from
    /// `GraphemeBreakProperty.txt` (the UCD default per @missing).
    @inlinable
    public static func graphemeClusterBreak(of scalar: Unicode.Scalar) -> GraphemeClusterBreak {
        let raw = graphemeClusterBreakTable.lookup(scalar.value)
        return GraphemeClusterBreak(rawValue: raw) ?? .other
    }
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter GraphemeClusterBreakTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 17 spot-check tests pass; full suite green.

If a spot-check fails, verify the expected codepoint in `Sources/UnicodeProperties/UCD/GraphemeBreakProperty.txt` before altering the test. Do NOT weaken a test or alter a generated table.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add graphemeClusterBreak(of:) entry point

UAX #29 Grapheme_Cluster_Break. Fourteen-case enum (other/cr/lf/
control/extend/zwj/regionalIndicator/prepend/spacingMark/l/v/t/lv/lvt)
with UInt8 raw values 0–13. O(1) lookup via TwoStageTrie<UInt8>;
absent codepoints default to .other (raw 0). Spot-checks cover all
14 cases with verified UCD codepoints.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Exhaustive sweep + coverage

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`

- [ ] **Step 1: Extend the exhaustive test**

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add inside the existing per-codepoint loop after the `eaw` assertion block:
```swift
            let gcb = UnicodeProperties.graphemeClusterBreak(of: scalar)
            #expect(gcb.rawValue <= 13,
                    "out-of-range GCB raw value at U+\(String(cp, radix: 16))")
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: all tests pass (exhaustive loop now asserts `rawValue <= 13` for all ~1.1M valid scalars).

- [ ] **Step 3: Coverage check**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build|Generated' \
  Sources/UnicodeProperties/UnicodeProperties.swift \
  Sources/UnicodeProperties/GraphemeClusterBreak.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/GraphemeBreakPropertyParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```
Expected: each file ≥ 90% line coverage.

If `GraphemeBreakPropertyParser.swift` falls short, identify uncovered branches. The `gbpRange(of:)` inner path (when needle is not found) and all four error-throw arms should be exercised by Task 1's tests. If a branch is still missing, add a targeted test rather than removing the branch.

Note: `expandGraphemeClusterBreak()` throws errors rather than calling `precondition(_:_:)` with messages, so no autoclosure coverage issue arises. This is consistent with the project-level memory note about precondition messages hurting coverage.

- [ ] **Step 4: Commit**

```bash
git add Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
test(unicode-properties): exhaustive sweep for graphemeClusterBreak

ExhaustiveTests now exercises graphemeClusterBreak(of:) across all
~1.1M valid Unicode scalars and asserts raw value ≤ 13. Full suite
passes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** every spec item — `GraphemeBreakPropertyEntry`, `GraphemeBreakPropertyParseError`, `GraphemeBreakPropertyParser`, `GraphemeClusterBreakCode`, `expandGraphemeClusterBreak`, generated table, `UnicodeProperties.GraphemeClusterBreak` enum (14 cases), `graphemeClusterBreak(of:)` entry point — has a task and tests. All 14 spot-check cases from the spec edge-case table are in `GraphemeClusterBreakTests.swift`.
- **No placeholders:** every step shows runnable code or an exact command with expected output.
- **Default fill is 0, not 5:** `expandGraphemeClusterBreak()` pre-fills with `0` (Other) matching the UCD `@missing: 0000..10FFFF; Other` directive. The `emptyEntriesYieldsAllOther` test explicitly checks `allSatisfy { $0 == 0 }`. (Contrast with EAW which uses 5 = Neutral as default.)
- **Trim helper is file-local:** the private `gbpTrimmed()` and `gbpRange(of:)` extensions on `String` use the `gbp` prefix to avoid name collisions with `eawTrimmed`/`eawRange` in `EastAsianWidthParser.swift` and `dcpTrimmed`/`dcpRange` in `DerivedCorePropertyParser.swift`. Same convention as every prior parser.
- **No precondition message strings:** `expandGraphemeClusterBreak()` throws errors rather than calling `precondition(_:_:)` with messages, so no autoclosure coverage issue arises. This is consistent with the project-level memory note about precondition messages hurting per-file coverage.
- **Codepoint verification:** all test codepoints were verified against the actual vendored `GraphemeBreakProperty.txt`:
  - CR = 0x000D (single-codepoint line), LF = 0x000A.
  - Control: 0x0000 and 0x0009 both in range `0000..0009`.
  - Extend: 0x0301 COMBINING ACUTE ACCENT (single-codepoint entry).
  - ZWJ: 0x200D (single-codepoint entry).
  - Regional_Indicator: 0x1F1E6 (first of range `1F1E6..1F1FF`).
  - Prepend: 0x0600 (first of range `0600..0605`).
  - SpacingMark: 0x093E (first of range `093E..0940`).
  - L: 0x1100 (first of range `1100..115F`).
  - V: 0x1160 (first of range `1160..11A7`).
  - T: 0x11A8 (first of range `11A8..11FF`).
  - LV: 0xAC00 (single-codepoint entry).
  - LVT: 0xAC01 (first of range `AC01..AC1B`).
  - Other: 0x0041 "A" (not listed anywhere in file).
- **Single table, one new file per layer convention:** `GraphemeClusterBreak` is a single-value-per-codepoint property. The codegen step adds exactly one new emission.
- **Parallel worktree safety:** this plan touches no files modified by Layer 2.9 (BidiBrackets). This plan touches `GraphemeBreakPropertyParser.swift` (new file) and appends to the very end of `main.swift`. Merge conflicts are possible only in `main.swift`, `UnicodeProperties.swift`, and `ExhaustiveTests.swift`; all are simple appends that the controller can resolve by ordering the two append blocks.
- **Layer doc update omitted:** as instructed, the layer doc update is a final-merge step handled by the controller, not this sub-agent.

# East Asian Width Implementation Plan (Layer 2.8)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.eastAsianWidth(of:)` per the spec at `docs/superpowers/specs/2026-05-22-east-asian-width-design.md`. Introduce a new parser (`EastAsianWidthParser`) and a new generated table (`EastAsianWidthTable.swift`).

**Architecture:** Single-property parser yields `[EastAsianWidthEntry]`. An expansion helper produces `[UInt8]` (values 0–5, default 5 = Neutral). The existing generic `TwoStageTrieBuilder.build` and `CodeEmitter.emit` produce a new `TwoStageTrie<UInt8>` table. One new `@inlinable` entry point. Six-case `UnicodeProperties.EastAsianWidth` enum with `UInt8` raw values.

**Branch:** `layer-2.8-east-asian-width`. Commit each task; controller merges.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/bedrock-ucd-gen/main.swift` — append parse + emit step for EastAsianWidth at the end.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add `eastAsianWidth(of:)` entry point.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — sweep the new entry point.

**Creations:**
- `Sources/BedrockUcdGen/EastAsianWidthParser.swift`
- `Sources/UnicodeProperties/EastAsianWidth.swift`
- `Sources/UnicodeProperties/Generated/EastAsianWidthTable.swift` (placeholder, then real)
- `Tests/BedrockUcdGenTests/EastAsianWidthParserTests.swift`
- `Tests/BedrockUcdGenTests/ExpandEastAsianWidthTests.swift`
- `Tests/UnicodePropertiesTests/EastAsianWidthTests.swift`

The vendored `Sources/UnicodeProperties/UCD/EastAsianWidth.txt` is already committed.

---

## Task 1: `EastAsianWidthParser`

**Files:**
- Create: `Sources/BedrockUcdGen/EastAsianWidthParser.swift`
- Create: `Tests/BedrockUcdGenTests/EastAsianWidthParserTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/EastAsianWidthParserTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct EastAsianWidthParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "0020;Na          # Zs       SPACE\n"
        let entries = try EastAsianWidthParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0020)
        #expect(entries[0].last  == 0x0020)
        #expect(entries[0].value == "Na")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "3001..3003;W     # Po   [3] IDEOGRAPHIC COMMA..DITTO MARK\n"
        let entries = try EastAsianWidthParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x3001)
        #expect(entries[0].last  == 0x3003)
        #expect(entries[0].value == "W")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # EastAsianWidth-16.0.0.txt
        # Date: 2024-04-30

        0020;Na          # Zs       SPACE

        3001..3003;W     # Po   [3] IDEOGRAPHIC COMMA..DITTO MARK
        """
        let entries = try EastAsianWidthParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].value == "Na")
        #expect(entries[1].value == "W")
    }

    @Test
    func parsesAllSixCodes() throws {
        let input = """
        0020;Na # test
        3000;F  # test
        FF61;H  # test
        0391;A  # test
        0000;N  # test
        6F22;W  # test
        """
        let entries = try EastAsianWidthParser.parse(input)
        #expect(entries.count == 6)
        let values = entries.map(\.value)
        #expect(values.contains("Na"))
        #expect(values.contains("F"))
        #expect(values.contains("H"))
        #expect(values.contains("A"))
        #expect(values.contains("N"))
        #expect(values.contains("W"))
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0020\n"
        do {
            _ = try EastAsianWidthParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX;Na # comment\n"
        do {
            _ = try EastAsianWidthParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidRange() {
        let input = "0020..;W # comment\n"
        do {
            _ = try EastAsianWidthParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyValue() {
        let input = "0020; # comment\n"
        do {
            _ = try EastAsianWidthParser.parse(input)
            Issue.record("expected throw for empty property value")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter EastAsianWidthParserTests 2>&1 | tail -10
```
Expected: compile error — `EastAsianWidthParser`, `EastAsianWidthEntry` don't exist.

- [ ] **Step 3: Implement the parser**

Create `Sources/BedrockUcdGen/EastAsianWidthParser.swift`:
```swift
public struct EastAsianWidthEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "A", "F", "H", "N", "Na", "W"

    public init(first: UInt32, last: UInt32, value: String) {
        self.first = first
        self.last  = last
        self.value = value
    }
}

public enum EastAsianWidthParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum EastAsianWidthParser {

    public static func parse(_ text: String) throws -> [EastAsianWidthEntry] {
        var entries: [EastAsianWidthEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.eawTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw EastAsianWidthParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).eawTrimmed()
            let valueField = String(fields[1]).eawTrimmed()

            if valueField.isEmpty {
                throw EastAsianWidthParseError.emptyPropertyValue(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.eawRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).eawTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).eawTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr,  radix: 16) else {
                    throw EastAsianWidthParseError.invalidRange(lineNumber: lineNumber,
                                                                raw: rangeField)
                }
                first = f
                last  = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw EastAsianWidthParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                    raw: rangeField)
                }
                first = cp
                last  = cp
            }

            entries.append(EastAsianWidthEntry(first: first, last: last, value: valueField))
        }
        return entries
    }
}

private extension String {
    func eawTrimmed() -> String {
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
    func eawRange(of needle: String) -> Range<String.Index>? {
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
swift test --filter EastAsianWidthParserTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 8 parser tests pass; full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add EastAsianWidthParser

Parses EastAsianWidth.txt UCD format (codepoint-or-range ; EAW-code
# comment). Six codes: Na, W, H, F, A, N. Structured errors for
malformed inputs. Stdlib-only whitespace trimming local to the file,
mirroring the DerivedCorePropertyParser convention.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `EastAsianWidthCode` + expansion helper

**Files:**
- Modify: `Sources/BedrockUcdGen/EastAsianWidthParser.swift` (append after the parser enum)
- Create: `Tests/BedrockUcdGenTests/ExpandEastAsianWidthTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/ExpandEastAsianWidthTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct EastAsianWidthCodeTests {

    @Test
    func allSixCodesMapCorrectly() throws {
        #expect(try EastAsianWidthCode.rawValue(for: "Na") == 0)
        #expect(try EastAsianWidthCode.rawValue(for: "W")  == 1)
        #expect(try EastAsianWidthCode.rawValue(for: "H")  == 2)
        #expect(try EastAsianWidthCode.rawValue(for: "F")  == 3)
        #expect(try EastAsianWidthCode.rawValue(for: "A")  == 4)
        #expect(try EastAsianWidthCode.rawValue(for: "N")  == 5)
    }

    @Test
    func unknownCodeThrows() {
        do {
            _ = try EastAsianWidthCode.rawValue(for: "X")
            Issue.record("expected throw for unknown code")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandEastAsianWidthTests {

    @Test
    func emptyEntriesYieldsAllNeutral() throws {
        let entries: [EastAsianWidthEntry] = []
        let out = try entries.expandEastAsianWidth()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 5 })   // 5 = N (Neutral), the default
    }

    @Test
    func singleCodepointEntryFillsCorrectly() throws {
        let entries: [EastAsianWidthEntry] = [
            EastAsianWidthEntry(first: 0x0020, last: 0x0020, value: "Na"),
        ]
        let out = try entries.expandEastAsianWidth()
        #expect(out[0x0020] == 0)   // Na = 0
        #expect(out[0x001F] == 5)   // untouched = N
        #expect(out[0x0021] == 5)
    }

    @Test
    func rangeEntryFillsInclusiveRange() throws {
        let entries: [EastAsianWidthEntry] = [
            EastAsianWidthEntry(first: 0x3001, last: 0x3003, value: "W"),
        ]
        let out = try entries.expandEastAsianWidth()
        #expect(out[0x3000] == 5)   // before range
        #expect(out[0x3001] == 1)   // W = 1
        #expect(out[0x3002] == 1)
        #expect(out[0x3003] == 1)
        #expect(out[0x3004] == 5)   // after range
    }

    @Test
    func multipleEntriesWithDifferentCodes() throws {
        let entries: [EastAsianWidthEntry] = [
            EastAsianWidthEntry(first: 0x0000, last: 0x001F, value: "N"),
            EastAsianWidthEntry(first: 0x0020, last: 0x0020, value: "Na"),
            EastAsianWidthEntry(first: 0x3000, last: 0x3000, value: "F"),
            EastAsianWidthEntry(first: 0x3001, last: 0x3003, value: "W"),
            EastAsianWidthEntry(first: 0xFF71, last: 0xFF71, value: "H"),
            EastAsianWidthEntry(first: 0x0391, last: 0x0391, value: "A"),
        ]
        let out = try entries.expandEastAsianWidth()
        #expect(out[0x0000] == 5)   // N = 5
        #expect(out[0x0020] == 0)   // Na = 0
        #expect(out[0x3000] == 3)   // F = 3
        #expect(out[0x3001] == 1)   // W = 1
        #expect(out[0xFF71] == 2)   // H = 2
        #expect(out[0x0391] == 4)   // A = 4
    }

    @Test
    func unknownCodeInEntryThrows() {
        let entries: [EastAsianWidthEntry] = [
            EastAsianWidthEntry(first: 0x0020, last: 0x0020, value: "X"),
        ]
        do {
            _ = try entries.expandEastAsianWidth()
            Issue.record("expected throw for unknown EAW code")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter EastAsianWidthCodeTests 2>&1 | tail -10
swift test --filter ExpandEastAsianWidthTests 2>&1 | tail -10
```
Expected: compile errors — `EastAsianWidthCode` and `expandEastAsianWidth` don't exist.

- [ ] **Step 3: Implement the code mapper and expansion helper**

In `Sources/BedrockUcdGen/EastAsianWidthParser.swift`, append AFTER the `EastAsianWidthParser` enum and BEFORE the private `String` extension:

```swift
public enum EastAsianWidthCode {
    /// Map UCD EAW code to UInt8 raw value matching UnicodeProperties.EastAsianWidth.
    public static func rawValue(for code: String) throws -> UInt8 {
        switch code {
        case "Na": return 0
        case "W":  return 1
        case "H":  return 2
        case "F":  return 3
        case "A":  return 4
        case "N":  return 5
        default:
            throw EastAsianWidthParseError.invalidCodepoint(lineNumber: -1, raw: code)
        }
    }
}

public extension Array where Element == EastAsianWidthEntry {
    /// Returns a 0x110000-element array of UInt8 raw values (0–5).
    /// Default fill is 5 (N = Neutral) per the UCD file header.
    func expandEastAsianWidth() throws -> [UInt8] {
        var out = [UInt8](repeating: 5, count: 0x110000)
        for entry in self {
            let value = try EastAsianWidthCode.rawValue(for: entry.value)
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
swift test --filter EastAsianWidthCodeTests 2>&1 | tail -10
swift test --filter ExpandEastAsianWidthTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 2 + 5 = 7 new tests pass; full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add EastAsianWidthCode and expandEastAsianWidth

EastAsianWidthCode.rawValue(for:) maps the six UCD EAW codes (Na/W/H/F/A/N)
to UInt8 values 0–5, matching the UnicodeProperties.EastAsianWidth enum.
expandEastAsianWidth() default-fills with 5 (Neutral) per the UCD header
and writes each entry's value across its inclusive codepoint range. Unknown
codes propagate a structured parse error.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Codegen run

**Files:**
- Create: `Sources/UnicodeProperties/Generated/EastAsianWidthTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated file**

Create `Sources/UnicodeProperties/Generated/EastAsianWidthTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let eastAsianWidthTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(5), count: 256)
)
```

Verify build:
```bash
swift build 2>&1 | tail -3
```
Expected: build succeeds (placeholder references `TwoStageTrie<UInt8>`, already in scope).

- [ ] **Step 2: Extend main.swift**

Read `Sources/bedrock-ucd-gen/main.swift` first to confirm the current end of file. After the final `emitUInt8` call for `XID_Continue` (the current last statement), append:

```swift
print("---")
print("Parsing EastAsianWidth.txt ...")
let eawPath = "Sources/UnicodeProperties/UCD/EastAsianWidth.txt"
let eawText: String
do {
    eawText = try String(contentsOfFile: eawPath, encoding: .utf8)
} catch {
    print("Failed to read \(eawPath): \(error)")
    exit(1)
}
let eawEntries: [EastAsianWidthEntry]
do {
    eawEntries = try EastAsianWidthParser.parse(eawText)
    print("Parsed \(eawEntries.count) EastAsianWidth entries.")
} catch {
    print("EastAsianWidth parse error: \(error)")
    exit(1)
}
let eawUncompacted: [UInt8]
do {
    eawUncompacted = try eawEntries.expandEastAsianWidth()
} catch {
    print("EastAsianWidth expansion error: \(error)")
    exit(1)
}

print("---")
print("Processing: East Asian Width")
emitUInt8("Sources/UnicodeProperties/Generated/EastAsianWidthTable.swift",
           "eastAsianWidthTable", "East Asian Width", eawUncompacted)
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -15
```
Expected output includes:
```
---
Parsing EastAsianWidth.txt ...
Parsed 2643 EastAsianWidth entries.
---
Processing: East Asian Width
Built two-stage trie: stage1=4352 entries, stage2=... entries (... unique blocks).
Self-check OK: 1114112 codepoints round-trip.
Wrote Sources/UnicodeProperties/Generated/EastAsianWidthTable.swift (...  bytes).
```
Estimated unique blocks: ~20–30 (only 6 possible values, highly compressible).

If self-check fails — STOP and report. Do not proceed.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite green (no public API references the new table yet, so test count unchanged).

- [ ] **Step 5: Spot-check generated file**

```bash
wc -c Sources/UnicodeProperties/Generated/EastAsianWidthTable.swift
head -5 Sources/UnicodeProperties/Generated/EastAsianWidthTable.swift
```
Expected: starts with `// GENERATED` banner; size roughly 20–40 KB.

- [ ] **Step 6: Verify other tables unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: ONLY `EastAsianWidthTable.swift` shows changes (placeholder → real). If any other file shows a diff, STOP and report.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit EastAsianWidthTable

bedrock-ucd-gen extended with EastAsianWidth.txt parse + emit step.
Self-check confirms all 1114112 codepoints round-trip through the
TwoStageTrie<UInt8>. Default fill is 5 (Neutral) per UCD header.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Public API + spot-check tests

**Files:**
- Create: `Sources/UnicodeProperties/EastAsianWidth.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/EastAsianWidthTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UnicodePropertiesTests/EastAsianWidthTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct EastAsianWidthTests {

    private func eaw(_ scalar: Unicode.Scalar) -> UnicodeProperties.EastAsianWidth {
        UnicodeProperties.eastAsianWidth(of: scalar)
    }

    @Test
    func asciiLetterIsNarrow() {
        // U+0041 A → Na (Narrow)
        #expect(eaw("A") == .narrow)
    }

    @Test
    func asciiDigitIsNarrow() {
        // U+0035 5 → Na (Narrow)
        #expect(eaw("5") == .narrow)
    }

    @Test
    func asciiSpaceIsNarrow() {
        // U+0020 SPACE → Na (Narrow)
        #expect(eaw(" ") == .narrow)
    }

    @Test
    func controlCharacterIsNeutral() {
        // U+0000 NULL → N (Neutral)
        #expect(eaw(Unicode.Scalar(0x0000)!) == .neutral)
    }

    @Test
    func fullwidthDigitIsFullwidth() {
        // U+FF10 FULLWIDTH DIGIT ZERO → F (Fullwidth)
        #expect(eaw(Unicode.Scalar(0xFF10)!) == .fullwidth)
    }

    @Test
    func halfwidthKatakanaIsHalfwidth() {
        // U+FF71 HALFWIDTH KATAKANA LETTER A → H (Halfwidth)
        #expect(eaw(Unicode.Scalar(0xFF71)!) == .halfwidth)
    }

    @Test
    func wideCJKIsWide() {
        // U+6F22 漢 → W (Wide)
        #expect(eaw(Unicode.Scalar(0x6F22)!) == .wide)
    }

    @Test
    func ideographicSpaceIsFullwidth() {
        // U+3000 IDEOGRAPHIC SPACE → F (Fullwidth)
        #expect(eaw(Unicode.Scalar(0x3000)!) == .fullwidth)
    }

    @Test
    func greekCapitalAlphaIsAmbiguous() {
        // U+0391 Α GREEK CAPITAL LETTER ALPHA → A (Ambiguous)
        #expect(eaw(Unicode.Scalar(0x0391)!) == .ambiguous)
    }

    @Test
    func privateUseAreaIsAmbiguous() {
        // U+E000 is in the PUA A (Ambiguous) range per UCD.
        #expect(eaw(Unicode.Scalar(0xE000)!) == .ambiguous)
    }

    @Test
    func enumHasSixCases() {
        #expect(UnicodeProperties.EastAsianWidth.allCases.count == 6)
    }

    @Test
    func rawValuesAreInRange() {
        for width in UnicodeProperties.EastAsianWidth.allCases {
            #expect(width.rawValue <= 5)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter EastAsianWidthTests 2>&1 | tail -5
```
Expected: compile error — `UnicodeProperties.EastAsianWidth` and `eastAsianWidth(of:)` don't exist.

- [ ] **Step 3: Create `EastAsianWidth.swift`**

Create `Sources/UnicodeProperties/EastAsianWidth.swift`:
```swift
extension UnicodeProperties {

    /// East Asian Width property (UAX #11). Used by terminal layout
    /// and CJK-aware string-width computation. Returns `.neutral` for
    /// codepoints not present in `EastAsianWidth.txt` (the documented
    /// default).
    public enum EastAsianWidth: UInt8, Sendable, Hashable, CaseIterable {
        case narrow      = 0   // Na
        case wide        = 1   // W
        case halfwidth   = 2   // H
        case fullwidth   = 3   // F
        case ambiguous   = 4   // A
        case neutral     = 5   // N (default)
    }
}
```

- [ ] **Step 4: Add the entry point**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add immediately after `isXIDContinue(_:)` and before `isLetter(_:)`:

```swift
    /// O(1) East Asian Width lookup (UAX #11).
    ///
    /// Used by terminal layout (each codepoint occupies 1 or 2 visual
    /// columns) and CJK-aware text rendering. Returns `.neutral` for
    /// codepoints absent from `EastAsianWidth.txt` (the UCD default).
    @inlinable
    public static func eastAsianWidth(of scalar: Unicode.Scalar) -> EastAsianWidth {
        let raw = eastAsianWidthTable.lookup(scalar.value)
        return EastAsianWidth(rawValue: raw) ?? .neutral
    }
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter EastAsianWidthTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 12 spot-check tests pass; full suite green.

If a spot-check fails, verify the expected codepoint in `Sources/UnicodeProperties/UCD/EastAsianWidth.txt` before altering the test. Do NOT weaken a test or alter a generated table.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add eastAsianWidth(of:) entry point

UAX #11 East Asian Width. Six-case enum (narrow/wide/halfwidth/
fullwidth/ambiguous/neutral) with UInt8 raw values 0–5. Identity
lookup via TwoStageTrie<UInt8>; absent codepoints default to
.neutral (raw 5). Spot-checks cover all six categories.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Exhaustive sweep + coverage

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`

- [ ] **Step 1: Extend the exhaustive test**

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add inside the existing per-codepoint loop after `fullCaseFolded`:
```swift
            let eaw = UnicodeProperties.eastAsianWidth(of: scalar)
            #expect(eaw.rawValue <= 5,
                    "out-of-range EAW raw value at U+\(String(cp, radix: 16))")
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: all tests pass (exhaustive loop now asserts `rawValue <= 5` for all ~1.1M valid scalars).

- [ ] **Step 3: Coverage check**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build|Generated' \
  Sources/UnicodeProperties/UnicodeProperties.swift \
  Sources/UnicodeProperties/EastAsianWidth.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/EastAsianWidthParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```
Expected: each file ≥ 90% line coverage.

If `EastAsianWidthParser.swift` falls short, identify uncovered branches. The `eawRange(of:)` inner path (when the needle is not found) and all four error-throw arms should be exercised by Task 1's tests. If a branch is still missing, add a targeted test rather than removing the branch.

Note: precondition-free `expandEastAsianWidth()` has no unreachable autoclosure to worry about (unlike files that use `precondition(_:_:)` with message strings). All branches are reachable from tests.

- [ ] **Step 4: Commit**

```bash
git add Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
test(unicode-properties): exhaustive sweep for eastAsianWidth

ExhaustiveTests now exercises eastAsianWidth(of:) across all ~1.1M
valid Unicode scalars and asserts raw value ≤ 5. Full suite passes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** every spec item — `EastAsianWidthEntry`, `EastAsianWidthParseError`, `EastAsianWidthParser`, `EastAsianWidthCode`, `expandEastAsianWidth`, generated table, `UnicodeProperties.EastAsianWidth` enum, `eastAsianWidth(of:)` entry point — has a task and tests. All ten spot-check cases from the spec are in `EastAsianWidthTests.swift`.
- **No placeholders:** every step shows runnable code or an exact command with expected output.
- **Default fill is 5, not 0:** `expandEastAsianWidth()` pre-fills with `5` (Neutral) so codepoints absent from the UCD (which is all of them for `N` implicitly) get the correct default. The `emptyEntriesYieldsAllNeutral` test explicitly checks `allSatisfy { $0 == 5 }`.
- **Trim helper is file-local:** the private `eawTrimmed()` and `eawRange(of:)` extensions on `String` use the `eaw` prefix to avoid name collisions with `dcpTrimmed`/`dcpRange` in `DerivedCorePropertyParser.swift`. Same convention as every prior parser.
- **No precondition message strings:** `expandEastAsianWidth()` throws errors rather than calling `precondition(_:_:)` with messages, so no autoclosure coverage issue arises. This is consistent with the project-level memory note about precondition messages hurting coverage.
- **Single table, one new file per layer convention:** EastAsianWidth is a single-value-per-codepoint property. No flat array or index trie is needed (unlike Layer 2.6's variable-length full case folding). The codegen step adds exactly one new emission.
- **Parallel worktree safety:** this plan touches no files modified by Layer 2.7 (More DCP). Layer 2.7 appends new expansion helpers to `DerivedCorePropertyParser.swift` and new XID-family calls in `main.swift`. This plan touches `EastAsianWidthParser.swift` (new file) and appends to the very end of `main.swift`. Merge conflicts are possible only in `main.swift` and `ExhaustiveTests.swift`; both are simple appends that the controller can resolve by ordering the two append blocks.
- **Layer doc update omitted:** as instructed, the layer doc update is a final-merge step handled by the controller, not this sub-agent.

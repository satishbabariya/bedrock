# Bidi Brackets Implementation Plan (Layer 2.9)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.bidiBracketType(of:)` and `UnicodeProperties.pairedBracket(of:)` per the spec at `docs/superpowers/specs/2026-05-23-bidi-brackets-design.md`. Introduce a new parser (`BidiBracketsParser`), two generated tables (`BidiBracketTypeTable.swift`, `BidiPairedBracketTable.swift`), and a three-case `UnicodeProperties.BidiBracketType` enum.

**Architecture:** Single-file parser yields `[BidiBracketEntry]`. Two expansion helpers produce `[UInt8]` (type: 0/1/2, default 0 = none) and `[UInt32]` (paired codepoint, default 0 = no pair). The existing generic `TwoStageTrieBuilder.build` and `CodeEmitter.emit` produce two new trie tables. Two new `@inlinable` entry points. No ranges in the source file — every line is a single codepoint.

**Branch:** `layer-2.9-bidi-brackets`. Commit each task; controller merges.

**Worktree path:** `/Users/satishbabariya/Desktop/Bedrock/.worktrees/layer-2.9`

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/bedrock-ucd-gen/main.swift` — append parse + 2 emit steps after the East Asian Width block.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add `bidiBracketType(of:)` and `pairedBracket(of:)` after `eastAsianWidth(of:)`.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — add 2 lines sweeping both new entry points.

**Creations:**
- `Sources/BedrockUcdGen/BidiBracketsParser.swift`
- `Sources/UnicodeProperties/BidiBrackets.swift`
- `Sources/UnicodeProperties/Generated/BidiBracketTypeTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/BidiPairedBracketTable.swift` (placeholder, then real)
- `Tests/BedrockUcdGenTests/BidiBracketsParserTests.swift`
- `Tests/BedrockUcdGenTests/ExpandBidiBracketsTests.swift`
- `Tests/UnicodePropertiesTests/BidiBracketsTests.swift`

The vendored `Sources/UnicodeProperties/UCD/BidiBrackets.txt` is already committed (128 entries, no ranges).

---

## Task 1: `BidiBracketsParser`

**Files:**
- Create: `Sources/BedrockUcdGen/BidiBracketsParser.swift`
- Create: `Tests/BedrockUcdGenTests/BidiBracketsParserTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/BidiBracketsParserTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct BidiBracketsParserTests {

    @Test
    func parsesSingleOpenEntry() throws {
        let input = "0028; 0029; o # LEFT PARENTHESIS\n"
        let entries = try BidiBracketsParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].codepoint       == 0x0028)
        #expect(entries[0].pairedCodepoint == 0x0029)
        #expect(entries[0].type            == .open)
    }

    @Test
    func parsesSingleCloseEntry() throws {
        let input = "0029; 0028; c # RIGHT PARENTHESIS\n"
        let entries = try BidiBracketsParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].codepoint       == 0x0029)
        #expect(entries[0].pairedCodepoint == 0x0028)
        #expect(entries[0].type            == .close)
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # BidiBrackets-16.0.0.txt
        # Date: 2024-02-02

        0028; 0029; o # LEFT PARENTHESIS

        0029; 0028; c # RIGHT PARENTHESIS
        """
        let entries = try BidiBracketsParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].type == .open)
        #expect(entries[1].type == .close)
    }

    @Test
    func parsesRealisticSnippetWithFileHeader() throws {
        let input = """
        # BidiBrackets-16.0.0.txt
        # Date: 2024-02-02
        # © 2024 Unicode®, Inc.

        0028; 0029; o # LEFT PARENTHESIS
        0029; 0028; c # RIGHT PARENTHESIS
        005B; 005D; o # LEFT SQUARE BRACKET
        005D; 005B; c # RIGHT SQUARE BRACKET
        007B; 007D; o # LEFT CURLY BRACKET
        007D; 007B; c # RIGHT CURLY BRACKET
        """
        let entries = try BidiBracketsParser.parse(input)
        #expect(entries.count == 6)
        #expect(entries[0].codepoint == 0x0028)
        #expect(entries[2].codepoint == 0x005B)
        #expect(entries[4].codepoint == 0x007B)
        #expect(entries[5].type == .close)
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0028; 0029\n"   // missing type field
        do {
            _ = try BidiBracketsParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX; 0029; o # comment\n"
        do {
            _ = try BidiBracketsParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidTypeCharacter() {
        let input = "0028; 0029; x # bad type\n"
        do {
            _ = try BidiBracketsParser.parse(input)
            Issue.record("expected throw for invalid type character")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter BidiBracketsParserTests 2>&1 | tail -10
```
Expected: compile error — `BidiBracketsParser`, `BidiBracketEntry` don't exist.

- [ ] **Step 3: Implement the parser**

Create `Sources/BedrockUcdGen/BidiBracketsParser.swift`:
```swift
public struct BidiBracketEntry: Equatable, Sendable {
    public let codepoint: UInt32
    public let pairedCodepoint: UInt32
    public let type: BracketType

    public enum BracketType: Character, Sendable {
        case open  = "o"
        case close = "c"
    }

    public init(codepoint: UInt32, pairedCodepoint: UInt32, type: BracketType) {
        self.codepoint       = codepoint
        self.pairedCodepoint = pairedCodepoint
        self.type            = type
    }
}

public enum BidiBracketsParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidType(lineNumber: Int, raw: String)
}

public enum BidiBracketsParser {

    public static func parse(_ text: String) throws -> [BidiBracketEntry] {
        var entries: [BidiBracketEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.bbTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            guard fields.count >= 3 else {
                throw BidiBracketsParseError.truncatedLine(lineNumber: lineNumber)
            }

            let cpField     = String(fields[0]).bbTrimmed()
            let pairedField = String(fields[1]).bbTrimmed()
            let typeField   = String(fields[2]).bbTrimmed()

            guard let cp = UInt32(cpField, radix: 16) else {
                throw BidiBracketsParseError.invalidCodepoint(lineNumber: lineNumber,
                                                              raw: cpField)
            }
            guard let paired = UInt32(pairedField, radix: 16) else {
                throw BidiBracketsParseError.invalidCodepoint(lineNumber: lineNumber,
                                                              raw: pairedField)
            }
            guard typeField.count == 1,
                  let typeChar = typeField.first,
                  let bracketType = BidiBracketEntry.BracketType(rawValue: typeChar) else {
                throw BidiBracketsParseError.invalidType(lineNumber: lineNumber,
                                                         raw: typeField)
            }

            entries.append(BidiBracketEntry(codepoint: cp,
                                            pairedCodepoint: paired,
                                            type: bracketType))
        }
        return entries
    }
}

private extension String {
    func bbTrimmed() -> String {
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
swift test --filter BidiBracketsParserTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 7 parser tests pass; full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add BidiBracketsParser

Parses BidiBrackets.txt UCD format (codepoint ; paired-codepoint ;
o|c # comment). No range form exists in the file — every line is a
single codepoint. BidiBracketEntry carries a nested BracketType enum
(Character raw value "o"/"c"). Structured errors for truncated lines,
non-hex codepoints, and invalid type characters. Stdlib-only whitespace
trimming with bb-prefixed helpers to avoid cross-file collisions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `expandBidiBracketType` + `expandBidiPairedBracket`

**Files:**
- Modify: `Sources/BedrockUcdGen/BidiBracketsParser.swift` (append after the parser enum)
- Create: `Tests/BedrockUcdGenTests/ExpandBidiBracketsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/ExpandBidiBracketsTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandBidiBracketsTests {

    @Test
    func emptyEntriesYieldsAllZeroTypeTable() {
        let entries: [BidiBracketEntry] = []
        let out = entries.expandBidiBracketType()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func emptyEntriesYieldsAllZeroPairedTable() {
        let entries: [BidiBracketEntry] = []
        let out = entries.expandBidiPairedBracket()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func openEntryWritesOneAndPaired() {
        let entries: [BidiBracketEntry] = [
            BidiBracketEntry(codepoint: 0x0028,
                             pairedCodepoint: 0x0029,
                             type: .open),
        ]
        let typeOut   = entries.expandBidiBracketType()
        let pairedOut = entries.expandBidiPairedBracket()
        #expect(typeOut[0x0028]   == 1)          // open = 1
        #expect(typeOut[0x0029]   == 0)          // untouched
        #expect(pairedOut[0x0028] == 0x0029)     // paired codepoint
        #expect(pairedOut[0x0029] == 0)          // untouched
    }

    @Test
    func closeEntryWritesTwoAndPaired() {
        let entries: [BidiBracketEntry] = [
            BidiBracketEntry(codepoint: 0x0029,
                             pairedCodepoint: 0x0028,
                             type: .close),
        ]
        let typeOut   = entries.expandBidiBracketType()
        let pairedOut = entries.expandBidiPairedBracket()
        #expect(typeOut[0x0029]   == 2)          // close = 2
        #expect(typeOut[0x0028]   == 0)          // untouched
        #expect(pairedOut[0x0029] == 0x0028)     // paired codepoint
        #expect(pairedOut[0x0028] == 0)          // untouched
    }

    @Test
    func multipleEntriesSetDistinctIndices() {
        let entries: [BidiBracketEntry] = [
            BidiBracketEntry(codepoint: 0x0028, pairedCodepoint: 0x0029, type: .open),
            BidiBracketEntry(codepoint: 0x0029, pairedCodepoint: 0x0028, type: .close),
            BidiBracketEntry(codepoint: 0x005B, pairedCodepoint: 0x005D, type: .open),
            BidiBracketEntry(codepoint: 0x005D, pairedCodepoint: 0x005B, type: .close),
        ]
        let typeOut   = entries.expandBidiBracketType()
        let pairedOut = entries.expandBidiPairedBracket()

        #expect(typeOut[0x0028]   == 1)
        #expect(typeOut[0x0029]   == 2)
        #expect(typeOut[0x005B]   == 1)
        #expect(typeOut[0x005D]   == 2)
        #expect(typeOut[0x0041]   == 0)          // 'A' — not a bracket

        #expect(pairedOut[0x0028] == 0x0029)
        #expect(pairedOut[0x0029] == 0x0028)
        #expect(pairedOut[0x005B] == 0x005D)
        #expect(pairedOut[0x005D] == 0x005B)
        #expect(pairedOut[0x0041] == 0)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter ExpandBidiBracketsTests 2>&1 | tail -10
```
Expected: compile errors — `expandBidiBracketType` and `expandBidiPairedBracket` don't exist.

- [ ] **Step 3: Implement the expansion helpers**

In `Sources/BedrockUcdGen/BidiBracketsParser.swift`, append AFTER the `BidiBracketsParser` enum and BEFORE the private `String` extension:

```swift
public extension Array where Element == BidiBracketEntry {
    /// Returns a 0x110000-element array of UInt8 type codes.
    /// Default 0 (none); 1 = open, 2 = close.
    func expandBidiBracketType() -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            switch entry.type {
            case .open:  out[Int(entry.codepoint)] = 1
            case .close: out[Int(entry.codepoint)] = 2
            }
        }
        return out
    }

    /// Returns a 0x110000-element array of UInt32 paired codepoints.
    /// Default 0 (no pair); nonzero = target codepoint.
    func expandBidiPairedBracket() -> [UInt32] {
        var out = [UInt32](repeating: 0, count: 0x110000)
        for entry in self {
            out[Int(entry.codepoint)] = entry.pairedCodepoint
        }
        return out
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter ExpandBidiBracketsTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 5 expansion tests pass; full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add expandBidiBracketType and expandBidiPairedBracket

expandBidiBracketType() default-fills 0 (none) and writes 1 for Open,
2 for Close codepoints. expandBidiPairedBracket() default-fills 0 and
writes each entry's paired codepoint. Neither can throw — the type
field is already a typed enum, so no unknown-code path exists.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Codegen run

**Files:**
- Create: `Sources/UnicodeProperties/Generated/BidiBracketTypeTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/BidiPairedBracketTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated files**

Create `Sources/UnicodeProperties/Generated/BidiBracketTypeTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let bidiBracketTypeTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(0), count: 256)
)
```

Create `Sources/UnicodeProperties/Generated/BidiPairedBracketTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let bidiPairedBracketTable = TwoStageTrie<UInt32>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt32(0), count: 256)
)
```

Verify build:
```bash
swift build 2>&1 | tail -3
```
Expected: build succeeds (placeholders reference `TwoStageTrie<UInt8>` and `TwoStageTrie<UInt32>`, already in scope).

- [ ] **Step 2: Extend main.swift**

Read `Sources/bedrock-ucd-gen/main.swift` first to confirm the current end of file is the East Asian Width `emitUInt8` call. Append the following block AFTER that final call:

```swift
print("---")
print("Parsing BidiBrackets.txt ...")
let bbPath = "Sources/UnicodeProperties/UCD/BidiBrackets.txt"
let bbText: String
do {
    bbText = try String(contentsOfFile: bbPath, encoding: .utf8)
} catch {
    print("Failed to read \(bbPath): \(error)")
    exit(1)
}
let bbEntries: [BidiBracketEntry]
do {
    bbEntries = try BidiBracketsParser.parse(bbText)
    print("Parsed \(bbEntries.count) BidiBracket entries.")
} catch {
    print("BidiBrackets parse error: \(error)")
    exit(1)
}

print("---")
print("Processing: Bidi Bracket Type")
emitUInt8("Sources/UnicodeProperties/Generated/BidiBracketTypeTable.swift",
           "bidiBracketTypeTable", "Bidi Bracket Type",
           bbEntries.expandBidiBracketType())

print("---")
print("Processing: Bidi Paired Bracket")
emitUInt32("Sources/UnicodeProperties/Generated/BidiPairedBracketTable.swift",
            "bidiPairedBracketTable", "Bidi Paired Bracket",
            bbEntries.expandBidiPairedBracket())
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -15
```
Expected output includes:
```
---
Parsing BidiBrackets.txt ...
Parsed 128 BidiBracket entries.
---
Processing: Bidi Bracket Type
Built two-stage trie: stage1=4352 entries, stage2=... entries (... unique blocks).
Self-check OK: 1114112 codepoints round-trip.
Wrote Sources/UnicodeProperties/Generated/BidiBracketTypeTable.swift (... bytes).
---
Processing: Bidi Paired Bracket
Built two-stage trie: stage1=4352 entries, stage2=... entries (... unique blocks).
Self-check OK: 1114112 codepoints round-trip.
Wrote Sources/UnicodeProperties/Generated/BidiPairedBracketTable.swift (... bytes).
```
Estimated unique blocks: <10 each (128 active codepoints out of 1.1M — extremely sparse).

If either self-check fails — STOP and report. Do not proceed.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite green (no public API references the new tables yet, so test count is unchanged).

- [ ] **Step 5: Spot-check generated files**

```bash
wc -c Sources/UnicodeProperties/Generated/BidiBracketTypeTable.swift
wc -c Sources/UnicodeProperties/Generated/BidiPairedBracketTable.swift
head -5 Sources/UnicodeProperties/Generated/BidiBracketTypeTable.swift
```
Expected: both files start with `// GENERATED` banner; size roughly 5–15 KB each.

- [ ] **Step 6: Verify only the two new tables changed**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: ONLY `BidiBracketTypeTable.swift` and `BidiPairedBracketTable.swift` show changes (placeholder → real). If any other file shows a diff, STOP and report.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit BidiBracketTypeTable and BidiPairedBracketTable

bedrock-ucd-gen extended with BidiBrackets.txt parse + 2 emit steps.
Self-check confirms all 1114112 codepoints round-trip through both
TwoStageTrie tables. Type table default fill is 0 (none); paired table
default fill is 0 (no pair). Sparse tables: 128 active codepoints.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Public API + spot-check tests

**Files:**
- Create: `Sources/UnicodeProperties/BidiBrackets.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/BidiBracketsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UnicodePropertiesTests/BidiBracketsTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct BidiBracketsTests {

    private func bbt(_ scalar: Unicode.Scalar) -> UnicodeProperties.BidiBracketType {
        UnicodeProperties.bidiBracketType(of: scalar)
    }

    private func pb(_ scalar: Unicode.Scalar) -> Unicode.Scalar? {
        UnicodeProperties.pairedBracket(of: scalar)
    }

    // --- bidiBracketType ---

    @Test
    func leftParenIsOpen() {
        #expect(bbt("(") == .open)
    }

    @Test
    func rightParenIsClose() {
        #expect(bbt(")") == .close)
    }

    @Test
    func asciiLetterIsNone() {
        #expect(bbt("A") == .none)
    }

    @Test
    func leftSquareBracketIsOpen() {
        #expect(bbt("[") == .open)
    }

    @Test
    func rightSquareBracketIsClose() {
        #expect(bbt("]") == .close)
    }

    @Test
    func leftCurlyBraceIsOpen() {
        #expect(bbt("{") == .open)
    }

    @Test
    func rightCurlyBraceIsClose() {
        #expect(bbt("}") == .close)
    }

    @Test
    func cjkLeftAngleBracketIsOpen() {
        // U+3008 LEFT ANGLE BRACKET → open
        #expect(bbt(Unicode.Scalar(0x3008)!) == .open)
    }

    @Test
    func cjkRightAngleBracketIsClose() {
        // U+3009 RIGHT ANGLE BRACKET → close
        #expect(bbt(Unicode.Scalar(0x3009)!) == .close)
    }

    // --- pairedBracket ---

    @Test
    func pairedOfLeftParenIsRightParen() {
        #expect(pb("(") == ")")
    }

    @Test
    func pairedOfRightParenIsLeftParen() {
        #expect(pb(")") == "(")
    }

    @Test
    func pairedOfAsciiLetterIsNil() {
        #expect(pb("A") == nil)
    }

    @Test
    func pairedOfSquareBrackets() {
        #expect(pb("[") == "]")
        #expect(pb("]") == "[")
    }

    @Test
    func pairedOfCurlyBraces() {
        #expect(pb("{") == "}")
        #expect(pb("}") == "{")
    }

    @Test
    func pairedOfCJKAngleBrackets() {
        // U+3008 ↔ U+3009
        #expect(pb(Unicode.Scalar(0x3008)!) == Unicode.Scalar(0x3009)!)
        #expect(pb(Unicode.Scalar(0x3009)!) == Unicode.Scalar(0x3008)!)
    }

    // --- enum sanity ---

    @Test
    func enumHasThreeCases() {
        #expect(UnicodeProperties.BidiBracketType.allCases.count == 3)
    }

    @Test
    func rawValuesAreInRange() {
        for t in UnicodeProperties.BidiBracketType.allCases {
            #expect(t.rawValue <= 2)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter BidiBracketsTests 2>&1 | tail -5
```
Expected: compile error — `UnicodeProperties.BidiBracketType`, `bidiBracketType(of:)`, and `pairedBracket(of:)` don't exist.

- [ ] **Step 3: Create `BidiBrackets.swift`**

Create `Sources/UnicodeProperties/BidiBrackets.swift`:
```swift
extension UnicodeProperties {

    /// Bidi paired bracket type (UAX #9, `Bidi_Paired_Bracket_Type`).
    /// Used by the UAX #9 bidi algorithm to handle paired brackets in
    /// mixed-directional text. Returns `.none` for codepoints that are
    /// not bracket characters (the default per UCD).
    public enum BidiBracketType: UInt8, Sendable, Hashable, CaseIterable {
        case none  = 0
        case open  = 1
        case close = 2
    }
}
```

- [ ] **Step 4: Add the entry points**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, insert immediately after `eastAsianWidth(of:)` and before `isLetter(_:)`:

```swift
    /// O(1) bracket-type lookup (UAX #9, `Bidi_Paired_Bracket_Type`).
    ///
    /// Returns `.none` for codepoints that are not bracket characters.
    @inlinable
    public static func bidiBracketType(of scalar: Unicode.Scalar) -> BidiBracketType {
        let raw = bidiBracketTypeTable.lookup(scalar.value)
        return BidiBracketType(rawValue: raw) ?? .none
    }

    /// O(1) paired-bracket lookup (UAX #9, `Bidi_Paired_Bracket`).
    ///
    /// Returns the mirrored partner codepoint for bracket characters
    /// (e.g., `(` → `)`, `[` → `]`). Returns `nil` for non-brackets.
    @inlinable
    public static func pairedBracket(of scalar: Unicode.Scalar) -> Unicode.Scalar? {
        let paired = bidiPairedBracketTable.lookup(scalar.value)
        return paired == 0 ? nil : Unicode.Scalar(paired)
    }
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter BidiBracketsTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 18 spot-check tests pass; full suite green.

If a spot-check fails, verify the expected codepoint in `Sources/UnicodeProperties/UCD/BidiBrackets.txt` before altering the test. Do NOT weaken a test or alter a generated table.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add bidiBracketType(of:) and pairedBracket(of:)

UAX #9 Bidi Brackets. Three-case BidiBracketType enum (none/open/close)
with UInt8 raw values 0–2. bidiBracketType(of:) returns .none for
non-bracket codepoints. pairedBracket(of:) returns the mirrored partner
scalar, nil for non-brackets. Spot-checks cover (, ), [, ], {, },
CJK angle brackets, and ASCII non-bracket.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Exhaustive sweep + coverage

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`

- [ ] **Step 1: Extend the exhaustive test**

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add inside the existing per-codepoint loop immediately after the `eastAsianWidth` assertion lines:
```swift
            let bbt = UnicodeProperties.bidiBracketType(of: scalar)
            #expect(bbt.rawValue <= 2,
                    "out-of-range BidiBracketType raw value at U+\(String(cp, radix: 16))")
            _ = UnicodeProperties.pairedBracket(of: scalar)
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: all tests pass (exhaustive loop now asserts `rawValue <= 2` for all ~1.1M valid scalars and discards the optional paired result).

- [ ] **Step 3: Coverage check**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build|Generated' \
  Sources/UnicodeProperties/UnicodeProperties.swift \
  Sources/UnicodeProperties/BidiBrackets.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/BidiBracketsParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```
Expected: each file ≥ 90% line coverage.

If `BidiBracketsParser.swift` falls short, identify uncovered branches. The `truncatedLine`, `invalidCodepoint`, and `invalidType` error arms should all be exercised by Task 1's tests. If a branch remains uncovered, add a targeted test rather than removing the branch.

Note: `expandBidiBracketType()` and `expandBidiPairedBracket()` do not throw — the `BracketType` switch is exhaustive and requires no error path. No precondition message strings are used, so no autoclosure coverage issue arises (consistent with the project memory note).

- [ ] **Step 4: Commit**

```bash
git add Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
test(unicode-properties): exhaustive sweep for bidiBracketType and pairedBracket

ExhaustiveTests now exercises bidiBracketType(of:) across all ~1.1M
valid Unicode scalars, asserting raw value ≤ 2, and discards the
optional result of pairedBracket(of:) for every scalar. Full suite
passes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** every spec item — `BidiBracketEntry`, `BidiBracketEntry.BracketType`, `BidiBracketsParseError`, `BidiBracketsParser`, `expandBidiBracketType`, `expandBidiPairedBracket`, two generated tables, `UnicodeProperties.BidiBracketType` enum, `bidiBracketType(of:)`, `pairedBracket(of:)` — has a task and tests. All nine spot-check cases listed in the spec are represented in `BidiBracketsTests.swift` (plus additional coverage for square brackets, curly braces, and raw-value range sanity).
- **No placeholders:** every step shows runnable code or an exact command with expected output.
- **Default fill is 0 throughout:** both expansion helpers pre-fill with 0. The type table's 0 maps to `.none`; the paired table's 0 signals "no pair" and causes `pairedBracket(of:)` to return `nil`. The `emptyEntriesYields...` tests explicitly confirm `allSatisfy { $0 == 0 }`.
- **No range form in source file:** `BidiBrackets.txt` has no `..` ranges. The parser requires exactly 3 semicolon-separated fields and does not need a range-splitting path. This removes an entire class of parsing complexity compared to `EastAsianWidthParser`.
- **Trim helper is file-local:** the private `bbTrimmed()` extension on `String` uses the `bb` prefix to avoid name collisions with `eawTrimmed` in `EastAsianWidthParser.swift` and `dcpTrimmed` in `DerivedCorePropertyParser.swift`. Same convention as every prior parser.
- **No precondition message strings:** neither expansion helper uses `precondition(_:_:)` with a message string. `expandBidiBracketType()` uses an exhaustive `switch` over a typed `BracketType` enum — no unknown-code path exists. This avoids the coverage autoclosure issue noted in the project memory.
- **Two tables, two entry points:** this layer is structurally distinct from EastAsianWidth (one table, one entry point). The `emitUInt8` + `emitUInt32` pair already exists in `main.swift`; both helpers are called in Task 3 without modification to the helpers themselves.
- **`pairedBracket` returns `Optional<Unicode.Scalar>`:** the sentinel value 0 is safe because U+0000 is never a valid paired bracket in `BidiBrackets.txt`. The spec explicitly states `paired == 0 ? nil : Unicode.Scalar(paired)`.
- **Parallel worktree safety:** this plan touches no files modified by Layer 2.10 (GraphemeBreakProperty). Both layers append to `main.swift` and `ExhaustiveTests.swift`, but only at the very end — simple ordered appends. Merge conflicts are limited to those two files and trivially resolved by the controller.
- **Layer doc update omitted:** as instructed, the layer doc update is a final-merge step handled by the controller, not this sub-agent.

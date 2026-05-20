# Simple Case Folding Implementation Plan (Layer 2.4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.caseFolded(of:)` per the spec at `docs/superpowers/specs/2026-05-20-simple-case-folding-design.md`. Introduce a second UCD parser (`CaseFoldingParser`) and a new generated table backed by the existing `TwoStageTrie<UInt32>` infrastructure.

**Architecture:** A new `CaseFoldingEntry` value type + `CaseFoldingParser` consume the already-vendored `CaseFolding.txt`. A new expansion helper produces a 0x110000-element `[UInt32]`. The existing generic `TwoStageTrieBuilder.build` and `CodeEmitter.emit` produce a third UInt32 table. The library exposes one new `@inlinable` entry point.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/bedrock-ucd-gen/main.swift` — add a third emission step after the existing two loops.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add `caseFolded(of:)` entry point.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — sweep the new entry point.

**Creations:**
- `Sources/BedrockUcdGen/CaseFoldingParser.swift`
- `Sources/UnicodeProperties/CaseFolding.swift` (comment-only marker)
- `Sources/UnicodeProperties/Generated/SimpleCaseFoldingTable.swift` (placeholder, then real)
- `Tests/UnicodePropertiesTests/CaseFoldingTests.swift`
- `Tests/BedrockUcdGenTests/CaseFoldingParserTests.swift`
- `Tests/BedrockUcdGenTests/ExpandSimpleCaseFoldingTests.swift`

The vendored `Sources/UnicodeProperties/UCD/CaseFolding.txt` is already committed (separate prior commit).

---

## Task 1: CaseFoldingEntry + CaseFoldingParser

**Files:**
- Create: `Sources/BedrockUcdGen/CaseFoldingParser.swift`
- Create: `Tests/BedrockUcdGenTests/CaseFoldingParserTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/CaseFoldingParserTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct CaseFoldingParserTests {

    @Test
    func parsesCommonEntry() throws {
        let input = "0041; C; 0061; # LATIN CAPITAL LETTER A\n"
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].codepoint == 0x0041)
        #expect(entries[0].status == .common)
        #expect(entries[0].mapping == [0x0061])
    }

    @Test
    func parsesFullEntry() throws {
        let input = "00DF; F; 0073 0073; # LATIN SMALL LETTER SHARP S\n"
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].codepoint == 0x00DF)
        #expect(entries[0].status == .full)
        #expect(entries[0].mapping == [0x0073, 0x0073])
    }

    @Test
    func parsesSimpleEntry() throws {
        let input = "1E9E; S; 00DF; # LATIN CAPITAL LETTER SHARP S\n"
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].status == .simple)
        #expect(entries[0].mapping == [0x00DF])
    }

    @Test
    func parsesTurkicEntry() throws {
        let input = "0130; T; 0069; # LATIN CAPITAL LETTER I WITH DOT ABOVE\n"
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].status == .turkic)
        #expect(entries[0].mapping == [0x0069])
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # CaseFolding-16.0.0.txt
        # Comment line

        0041; C; 0061; # LATIN CAPITAL LETTER A

        # Another comment
        0042; C; 0062; # LATIN CAPITAL LETTER B
        """
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].codepoint == 0x0041)
        #expect(entries[1].codepoint == 0x0042)
    }

    @Test
    func parsesMixedStatusesInRealisticInput() throws {
        let input = """
        # Header
        0041; C; 0061; # LATIN CAPITAL LETTER A
        00DF; F; 0073 0073; # ß
        0130; F; 0069 0307; # İ full
        0130; T; 0069; # İ turkic
        1E9E; S; 00DF; # ẞ
        """
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 5)
        #expect(entries[0].status == .common)
        #expect(entries[1].status == .full)
        #expect(entries[2].status == .full)
        #expect(entries[3].status == .turkic)
        #expect(entries[4].status == .simple)
    }

    @Test
    func rejectsInvalidStatus() {
        let input = "0041; Z; 0061;\n"
        do {
            _ = try CaseFoldingParser.parse(input)
            Issue.record("expected throw for invalid status")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX; C; 0061;\n"
        do {
            _ = try CaseFoldingParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyMapping() {
        let input = "0041; C; ;\n"
        do {
            _ = try CaseFoldingParser.parse(input)
            Issue.record("expected throw for empty mapping")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0041; C;\n"  // only 2 fields
        do {
            _ = try CaseFoldingParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter CaseFoldingParserTests 2>&1 | tail -10
```
Expected: compile error — `CaseFoldingParser`, `CaseFoldingEntry`, etc. don't exist.

- [ ] **Step 3: Implement CaseFoldingParser**

Create `Sources/BedrockUcdGen/CaseFoldingParser.swift`:
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
    public let mapping: [UInt32]

    public init(codepoint: UInt32, status: Status, mapping: [UInt32]) {
        self.codepoint = codepoint
        self.status = status
        self.mapping = mapping
    }
}

public enum CaseFoldingParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidStatus(lineNumber: Int, raw: String)
    case emptyMapping(lineNumber: Int)
}

public enum CaseFoldingParser {

    public static func parse(_ text: String) throws -> [CaseFoldingEntry] {
        var entries: [CaseFoldingEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            // Strip trailing #-comment.
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            // Trim whitespace.
            let trimmed = line.cfTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 3 {
                throw CaseFoldingParseError.truncatedLine(lineNumber: lineNumber)
            }
            let codepointField = String(fields[0]).cfTrimmed()
            let statusField    = String(fields[1]).cfTrimmed()
            let mappingField   = String(fields[2]).cfTrimmed()

            guard let codepoint = UInt32(codepointField, radix: 16) else {
                throw CaseFoldingParseError.invalidCodepoint(lineNumber: lineNumber,
                                                              raw: codepointField)
            }
            guard statusField.count == 1,
                  let statusChar = statusField.first,
                  let status = CaseFoldingEntry.Status(rawValue: statusChar) else {
                throw CaseFoldingParseError.invalidStatus(lineNumber: lineNumber,
                                                          raw: statusField)
            }
            if mappingField.isEmpty {
                throw CaseFoldingParseError.emptyMapping(lineNumber: lineNumber)
            }
            // Mapping is space-separated hex codepoints.
            var mapping: [UInt32] = []
            for token in mappingField.split(separator: " ", omittingEmptySubsequences: true) {
                guard let cp = UInt32(token, radix: 16) else {
                    throw CaseFoldingParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                  raw: String(token))
                }
                mapping.append(cp)
            }
            if mapping.isEmpty {
                throw CaseFoldingParseError.emptyMapping(lineNumber: lineNumber)
            }
            entries.append(CaseFoldingEntry(codepoint: codepoint,
                                             status: status,
                                             mapping: mapping))
        }
        return entries
    }
}

private extension String {
    /// Stdlib-only whitespace trim. Keeps this file independent of the
    /// trim helper in UCDParser.swift (which is fileprivate to that file).
    func cfTrimmed() -> String {
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
swift test --filter CaseFoldingParserTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 10 parser tests pass; full suite green at 626.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add CaseFoldingParser

Parses CaseFolding.txt UCD format (semicolon-separated fields with
#-comments). Four-case status enum (C/F/S/T). Mapping is
variable-length array of hex codepoints. Stdlib-only whitespace
trimming kept local to the file.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: expandSimpleCaseFolding helper

**Files:**
- Modify: `Sources/BedrockUcdGen/CaseFoldingParser.swift`
- Create: `Tests/BedrockUcdGenTests/ExpandSimpleCaseFoldingTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/ExpandSimpleCaseFoldingTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandSimpleCaseFoldingTests {

    @Test
    func emptyEntriesYieldsAllZeros() {
        let entries: [CaseFoldingEntry] = []
        let out = entries.expandSimpleCaseFolding()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func singleCommonEntryFillsOneCodepoint() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0041] == 0x0061)
        #expect(out[0x0040] == 0)
        #expect(out[0x0042] == 0)
    }

    @Test
    func singleSimpleEntryFillsOneCodepoint() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x1E9E, status: .simple, mapping: [0x00DF]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x1E9E] == 0x00DF)
    }

    @Test
    func fullEntryIsSkipped() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x00DF, status: .full, mapping: [0x0073, 0x0073]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x00DF] == 0)
    }

    @Test
    func turkicEntryIsSkipped() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0130, status: .turkic, mapping: [0x0069]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0130] == 0)
    }

    @Test
    func multiCodepointCommonMappingIsDefensivelySkipped() {
        // Synthetic: shouldn't occur in real UCD, but the helper should
        // skip it via the mapping.count == 1 filter.
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common,
                              mapping: [0x0061, 0x0062]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0041] == 0)
    }

    @Test
    func simpleOverridesCommonOnSameCodepoint() {
        // Synthetic: not present in real UCD 16.0, but the helper
        // should let S take priority over C.
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
            CaseFoldingEntry(codepoint: 0x0041, status: .simple, mapping: [0x0062]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0041] == 0x0062)
    }

    @Test
    func mixedRealisticInput() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
            CaseFoldingEntry(codepoint: 0x00DF, status: .full,   mapping: [0x0073, 0x0073]),
            CaseFoldingEntry(codepoint: 0x0130, status: .full,   mapping: [0x0069, 0x0307]),
            CaseFoldingEntry(codepoint: 0x0130, status: .turkic, mapping: [0x0069]),
            CaseFoldingEntry(codepoint: 0x1E9E, status: .simple, mapping: [0x00DF]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0041] == 0x0061)   // C used
        #expect(out[0x00DF] == 0)        // F skipped
        #expect(out[0x0130] == 0)        // F + T both skipped
        #expect(out[0x1E9E] == 0x00DF)   // S used
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter ExpandSimpleCaseFoldingTests 2>&1 | tail -10
```
Expected: compile error.

- [ ] **Step 3: Implement the helper**

Append to `Sources/BedrockUcdGen/CaseFoldingParser.swift` (after the parser, at file scope):

```swift
public extension Array where Element == CaseFoldingEntry {
    /// Expand to a 0x110000-element uncompacted [UInt32] containing the
    /// simple case-folded target codepoint (0 = identity).
    ///
    /// Honors statuses C and S only (single-codepoint mappings).
    /// If both exist for the same codepoint, S takes priority
    /// (Unicode-documented). F and T entries are skipped.
    func expandSimpleCaseFolding() -> [UInt32] {
        var out = [UInt32](repeating: 0, count: 0x110000)
        for entry in self
            where entry.status == .common && entry.mapping.count == 1 {
            out[Int(entry.codepoint)] = entry.mapping[0]
        }
        for entry in self
            where entry.status == .simple && entry.mapping.count == 1 {
            out[Int(entry.codepoint)] = entry.mapping[0]
        }
        return out
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter ExpandSimpleCaseFoldingTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 8 tests pass; full suite green at 634.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add expandSimpleCaseFolding helper

Two-pass write (C first, then S overrides). Filters to
mapping.count == 1 defensively. F and T entries skipped.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Codegen run + generated table

**Files:**
- Create: `Sources/UnicodeProperties/Generated/SimpleCaseFoldingTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated file**

Create `Sources/UnicodeProperties/Generated/SimpleCaseFoldingTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let simpleCaseFoldingTable = TwoStageTrie<UInt32>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt32(0), count: 256)
)
```

Verify build:
```bash
swift build 2>&1 | tail -3
```

- [ ] **Step 2: Extend main.swift**

In `Sources/bedrock-ucd-gen/main.swift`, after the existing two `for ... in uint8Outputs { ... }` and `for ... in uint32Outputs { ... }` loops (at the very end of the file), append:

```swift
print("---")
print("Processing: simple case folding (CaseFolding.txt)")
let cfPath = "Sources/UnicodeProperties/UCD/CaseFolding.txt"
let cfText: String
do {
    cfText = try String(contentsOfFile: cfPath, encoding: .utf8)
} catch {
    print("Failed to read \(cfPath): \(error)")
    exit(1)
}
let cfEntries: [CaseFoldingEntry]
do {
    cfEntries = try CaseFoldingParser.parse(cfText)
    print("Parsed \(cfEntries.count) folding entries.")
} catch {
    print("CaseFolding parse error: \(error)")
    exit(1)
}
let cfUncompacted = cfEntries.expandSimpleCaseFolding()
emitUInt32("Sources/UnicodeProperties/Generated/SimpleCaseFoldingTable.swift",
            "simpleCaseFoldingTable", "simple case folding", cfUncompacted)
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -15
```
Expected: existing 6 emissions plus a 7th for simple case folding. Each self-checks against the uncompacted source. The case-folding emission reports the parsed entry count (~1590) and the unique-block count.

If the self-check fails, the expansion helper or parser has a bug. STOP and investigate.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite still green at 634 (the new global is defined but no public API references it yet).

- [ ] **Step 5: Spot-check the generated file**

```bash
wc -c Sources/UnicodeProperties/Generated/SimpleCaseFoldingTable.swift
head -5 Sources/UnicodeProperties/Generated/SimpleCaseFoldingTable.swift
```
Expected: starts with the GENERATED banner; size ~25-45 KB.

- [ ] **Step 6: Verify the existing 6 tables are unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: only `SimpleCaseFoldingTable.swift` shows changes (the placeholder → real). No changes to the other six tables.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit simple-case-folding table

bedrock-ucd-gen extended with a third emission step (after the two
UnicodeData.txt loops): reads CaseFolding.txt, parses, expands to
[UInt32], emits SimpleCaseFoldingTable.swift via the existing generic
emitter. Per-property self-check confirms all 1114112 codepoints
round-trip.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Public API + spot-check tests

**Files:**
- Create: `Sources/UnicodeProperties/CaseFolding.swift` (comment-only marker)
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/CaseFoldingTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/UnicodePropertiesTests/CaseFoldingTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct CaseFoldingTests {

    private func folded(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        UnicodeProperties.caseFolded(of: scalar)
    }

    @Test
    func asciiUppercaseFoldsToLowercase() {
        #expect(folded("A") == "a")
        #expect(folded("Z") == "z")
        #expect(folded("M") == "m")
    }

    @Test
    func asciiLowercaseIsIdentity() {
        #expect(folded("a") == "a")
        #expect(folded("z") == "z")
    }

    @Test
    func asciiNonLettersIdentity() {
        #expect(folded("5") == "5")
        #expect(folded(" ") == " ")
        #expect(folded("!") == "!")
        #expect(folded("\u{0000}") == "\u{0000}")
    }

    @Test
    func latin1Uppercase() {
        // À U+00C0 -> à U+00E0
        #expect(folded(Unicode.Scalar(0x00C0)!) == Unicode.Scalar(0x00E0)!)
    }

    @Test
    func greekHeadline() {
        // Σ (U+03A3) and ς (U+03C2) BOTH fold to σ (U+03C3).
        let sigma = Unicode.Scalar(0x03C3)!
        #expect(folded(Unicode.Scalar(0x03A3)!) == sigma)
        #expect(folded(Unicode.Scalar(0x03C2)!) == sigma)
        #expect(folded(sigma) == sigma)
    }

    @Test
    func sharpSIdentityInV1() {
        // ß (U+00DF) has only an F entry; no simple folding in v1.
        let sharpS = Unicode.Scalar(0x00DF)!
        #expect(folded(sharpS) == sharpS)
    }

    @Test
    func turkishDottedIIdentityInV1() {
        // İ (U+0130) has F + T but no C/S; no simple folding in v1.
        let dottedI = Unicode.Scalar(0x0130)!
        #expect(folded(dottedI) == dottedI)
    }

    @Test
    func cjkIdentity() {
        let cjk = Unicode.Scalar(0x6F22)!
        #expect(folded(cjk) == cjk)
    }

    @Test
    func titlecaseLetterFoldsToLowercase() {
        // ǅ U+01C5 -> ǆ U+01C6
        #expect(folded(Unicode.Scalar(0x01C5)!) == Unicode.Scalar(0x01C6)!)
    }

    @Test
    func foldingEquivalenceHoldsAcrossCasePairs() {
        #expect(folded("A") == folded("a"))
        #expect(folded(Unicode.Scalar(0x03A3)!) == folded(Unicode.Scalar(0x03C2)!))
        #expect(folded(Unicode.Scalar(0x00C0)!) == folded(Unicode.Scalar(0x00E0)!))
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter CaseFoldingTests 2>&1 | tail -5
```
Expected: compile error.

- [ ] **Step 3: Add marker file**

Create `Sources/UnicodeProperties/CaseFolding.swift`:
```swift
// CaseFolding entry point lives in UnicodeProperties.swift to keep the
// namespace surface co-located with other property accessors. This file
// exists to match the file-per-property layout established by
// BidiClass.swift, CanonicalCombiningClass.swift, and SimpleCaseMapping.swift.
```

- [ ] **Step 4: Add the entry point**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add immediately after `simpleTitlecase(of:)` (and before the major-category helpers):

```swift
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
    public static func caseFolded(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        let raw = simpleCaseFoldingTable.lookup(scalar.value)
        return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
    }
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter CaseFoldingTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 10 spot-check tests pass; full suite green at 644.

If a Greek or Latin folding assertion fails, the codegen has a bug — investigate via the corresponding line in `CaseFolding.txt`. Do NOT alter the generated table.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add caseFolded(of:) entry point

Simple case folding for case-insensitive comparison. Maps Σ and ς
both to σ (the headline folding-equivalence result). Multi-codepoint
F entries and locale-dependent T entries deferred to separate
sub-projects.

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

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add one line inside the existing loop (after `simpleTitlecase`):
```swift
            _ = UnicodeProperties.caseFolded(of: scalar)
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: 644 tests pass; exhaustive test still completes in well under 2 seconds.

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
  Sources/UnicodeProperties/SimpleCaseMapping.swift \
  Sources/UnicodeProperties/CaseFolding.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/UCDParser.swift \
  Sources/BedrockUcdGen/CaseFoldingParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```
Expected: each file ≥ 90% line coverage.

If `CaseFoldingParser.swift` falls below 90%, identify uncovered lines via `xcrun llvm-cov show`. Most likely candidates: the error-throwing branches that the existing reject-tests already exercise. If a branch is genuinely defensive/unreachable, document the gap; don't fabricate tests.

- [ ] **Step 4: Update Layer 2 doc**

Edit `layers/layer-02-text-unicode.md`. Replace the existing Status block:

```markdown
> **Status:** shipping modules:
> - `Sources/UnicodeProperties/` — UCD-derived lookup against a two-stage trie. Properties available: general category (UAX #44), bidi class (UAX #9), canonical combining class, simple case mappings (uppercase/lowercase/titlecase), simple case folding (CaseFolding.txt C+S). Codegen tool `bedrock-ucd-gen` emits one table per property ([2.1 design](../docs/superpowers/specs/2026-05-19-unicode-properties-design.md) · [2.1 plan](../docs/superpowers/plans/2026-05-19-unicode-properties-module.md) · [2.2 design](../docs/superpowers/specs/2026-05-20-bidi-class-and-ccc-design.md) · [2.2 plan](../docs/superpowers/plans/2026-05-20-bidi-class-and-ccc-module.md) · [2.3 design](../docs/superpowers/specs/2026-05-20-simple-case-mapping-design.md) · [2.3 plan](../docs/superpowers/plans/2026-05-20-simple-case-mapping-module.md) · [2.4 design](../docs/superpowers/specs/2026-05-20-simple-case-folding-design.md) · [2.4 plan](../docs/superpowers/plans/2026-05-20-simple-case-folding-module.md)). Unicode 16.0.0.
>
> Subsequent sub-projects (Layer 2.5–2.8): normalization (NFC/NFD/NFKC/NFKD), segmentation (UAX #29), full case folding + SpecialCasing, identifier classification (UAX #31), bidi algorithm (UAX #9), ASCII helpers.
```

- [ ] **Step 5: Commit**

```bash
git add Tests/UnicodePropertiesTests layers/layer-02-text-unicode.md
git commit -m "$(cat <<'EOF'
test+docs(unicode-properties): exhaustive sweep + mark 2.4 shipped

ExhaustiveTests now exercises all seven properties across ~1.1M
codepoints. Layer 2 doc updated to include simple case folding.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(If coverage tests were added in Step 3, fold them in or commit separately.)

---

## Plan Self-Review Notes

- **Spec coverage:** Every spec item — `CaseFoldingEntry`, `CaseFoldingParser`, `expandSimpleCaseFolding`, generated table, `caseFolded(of:)` entry point — has a task. Every test category in the spec is covered.
- **No placeholders:** Every step shows runnable code or an exact command.
- **Type consistency:** `CaseFoldingEntry.Status` raw values are characters; status priority (S over C) is identical between expansion helper and tests; storage convention 0 = identity is consistent with prior case-mapping tables.
- **Reuses generic infrastructure:** `TwoStageTrieBuilder.build` and `CodeEmitter.emit` are unchanged from Layer 2.3's generalization; `emitUInt32` helper in `main.swift` is reused.
- **Two UCD source files:** This sub-project is the first time `main.swift` reads from a second UCD file. The placeholder table in Task 3 Step 1 ensures the package keeps building until the real table is emitted in Task 3 Step 3.
- **Trim helper:** Each parser file has its own private trim helper (`cfTrimmed`). Slight duplication with `UCDParser`'s `stdlibTrimmed` is acceptable — keeping them file-local avoids cross-file coupling for a 6-line stdlib utility.

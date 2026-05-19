# UnicodeProperties Module Implementation Plan (Layer 2.1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `UnicodeProperties` (library) and `bedrock-ucd-gen` (executable) per the spec at `docs/superpowers/specs/2026-05-19-unicode-properties-design.md`.

**Architecture:** Two SwiftPM targets. The library exposes a namespaced enum with a single property (`generalCategory(of:)`) backed by a two-stage trie. The executable parses the vendored `UnicodeData.txt` (Unicode 16.0), compacts the trie with block deduplication, and emits a Swift source file containing the literal tables. Both targets are stdlib-only.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing (`import Testing`, `@Test`, `#expect`, `@Suite`).

---

## File Structure

**Library** (`Sources/UnicodeProperties/`):
- `UnicodeProperties.swift` — namespace, entry points (`generalCategory(of:)`, helpers, `unicodeVersion`)
- `GeneralCategory.swift` — the enum (30 cases) + major-category helpers as enum methods
- `Internal/TwoStageTrie.swift` — `internal struct TwoStageTrie<Value: FixedWidthInteger>` with `@inlinable lookup`
- `Generated/GeneralCategoryTable.swift` — emitted by codegen; placeholder in T2, real file from T6 onward
- `UCD/UnicodeData.txt` — vendored Unicode 16.0.0 (already committed)

**Executable** (`Sources/bedrock-ucd-gen/`):
- `main.swift` — CLI entry, wires parser → builder → emitter
- `UCDParser.swift` — parses UnicodeData.txt format
- `TwoStageTrieBuilder.swift` — compacts uncompacted-array into stage1/stage2 with block dedup; self-check round-trip
- `CodeEmitter.swift` — formats stage1/stage2 into a Swift source file

**Tests**:
- `Tests/UnicodePropertiesTests/{GeneralCategoryTests,MajorCategoryHelperTests,BoundaryTests,RangedEntryTests,ExhaustiveTests,TwoStageTrieTests}.swift`
- `Tests/BedrockUcdGenTests/{UCDParserTests,TwoStageTrieBuilderTests,CodeEmitterTests}.swift`

Note: `bedrock-ucd-gen` is an executable target. To make its internals testable, we declare it as a library target named `BedrockUcdGen` plus a thin executable target that imports it and calls a single entry point.

---

## Task 1: Package scaffolding

**Files:**
- Modify: `Package.swift`
- Create: stub `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: stub `Sources/UnicodeProperties/Internal/TwoStageTrie.swift`
- Create: stub `Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift`
- Create: stub `Sources/BedrockUcdGen/UCDParser.swift`, `TwoStageTrieBuilder.swift`, `CodeEmitter.swift`
- Create: `Sources/bedrock-ucd-gen/main.swift` (thin entry)
- Create: stub tests

- [ ] **Step 1: Update Package.swift**

Add to `products:` after the TaggedPointer line:
```swift
.library(name: "UnicodeProperties", targets: ["UnicodeProperties"]),
.executable(name: "bedrock-ucd-gen", targets: ["bedrock-ucd-gen"]),
```

Add to `targets:` after the TaggedPointer test target:
```swift
.target(name: "UnicodeProperties",
        path: "Sources/UnicodeProperties",
        exclude: ["UCD"]),
.testTarget(name: "UnicodePropertiesTests",
            dependencies: ["UnicodeProperties"],
            path: "Tests/UnicodePropertiesTests"),

.target(name: "BedrockUcdGen",
        path: "Sources/BedrockUcdGen"),
.executableTarget(name: "bedrock-ucd-gen",
                  dependencies: ["BedrockUcdGen"],
                  path: "Sources/bedrock-ucd-gen"),
.testTarget(name: "BedrockUcdGenTests",
            dependencies: ["BedrockUcdGen"],
            path: "Tests/BedrockUcdGenTests"),
```

Important: `exclude: ["UCD"]` keeps the 2.1 MB vendored data out of the compiled library — it's only needed by the codegen tool.

- [ ] **Step 2: Create stub source files**

`Sources/UnicodeProperties/UnicodeProperties.swift`:
```swift
public enum UnicodeProperties {
}
```

`Sources/UnicodeProperties/Internal/TwoStageTrie.swift`:
```swift
// Placeholder; real implementation in Task 2.
```

`Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift`:
```swift
// Placeholder; real table generated in Task 6.
```

`Sources/BedrockUcdGen/UCDParser.swift`:
```swift
// Placeholder.
```

`Sources/BedrockUcdGen/TwoStageTrieBuilder.swift`:
```swift
// Placeholder.
```

`Sources/BedrockUcdGen/CodeEmitter.swift`:
```swift
// Placeholder.
```

`Sources/bedrock-ucd-gen/main.swift`:
```swift
import BedrockUcdGen

// Placeholder; real implementation in Task 6.
print("bedrock-ucd-gen scaffolded")
```

- [ ] **Step 3: Create stub tests**

`Tests/UnicodePropertiesTests/ScaffoldTests.swift`:
```swift
import Testing
import UnicodeProperties

@Test
func scaffoldCompiles() {
    #expect(Bool(true))
}
```

`Tests/BedrockUcdGenTests/ScaffoldTests.swift`:
```swift
import Testing
import BedrockUcdGen

@Test
func bedrockUcdGenScaffoldCompiles() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Verify**

Run: `swift build`
Expected: builds cleanly, zero warnings.

Run: `swift test --filter UnicodePropertiesTests`
Run: `swift test --filter BedrockUcdGenTests`
Run: `swift run bedrock-ucd-gen`
Expected: each succeeds. The executable prints "bedrock-ucd-gen scaffolded".

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/UnicodeProperties Sources/BedrockUcdGen Sources/bedrock-ucd-gen Tests/UnicodePropertiesTests Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): scaffold Layer 2.1 module

UnicodeProperties library + bedrock-ucd-gen executable + their test
targets. UCD directory excluded from library compilation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: TwoStageTrie primitive

**Files:**
- Modify: `Sources/UnicodeProperties/Internal/TwoStageTrie.swift`
- Modify: `Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift` (placeholder with all-zero tables)
- Create: `Tests/UnicodePropertiesTests/TwoStageTrieTests.swift`
- Delete: `Tests/UnicodePropertiesTests/ScaffoldTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UnicodePropertiesTests/TwoStageTrieTests.swift`:
```swift
import Testing
@testable import UnicodeProperties

@Suite
struct TwoStageTrieTests {

    @Test
    func allZeroTrieReturnsZero() {
        let trie = TwoStageTrie<UInt8>(
            stage1: Array(repeating: UInt16(0), count: 4352),
            stage2: Array(repeating: UInt8(0), count: 256)
        )
        #expect(trie.lookup(0x0000) == 0)
        #expect(trie.lookup(0x0041) == 0)
        #expect(trie.lookup(0xFFFF) == 0)
        #expect(trie.lookup(0x10FFFF) == 0)
    }

    @Test
    func twoBlockTrieRoutesCorrectly() {
        // Two blocks. Block 0 = all 7s; block 1 = all 42s.
        // stage1 routes codepoint >> 8 to a block index.
        var stage1 = Array(repeating: UInt16(0), count: 4352)
        // Codepoints 0x0100..0x01FF live in stage1 index 1; route to block 1.
        stage1[1] = 1
        let stage2: [UInt8] =
            Array(repeating: UInt8(7),  count: 256) +
            Array(repeating: UInt8(42), count: 256)
        let trie = TwoStageTrie<UInt8>(stage1: stage1, stage2: stage2)
        #expect(trie.lookup(0x0000) == 7)
        #expect(trie.lookup(0x00FF) == 7)
        #expect(trie.lookup(0x0100) == 42)
        #expect(trie.lookup(0x01FF) == 42)
        #expect(trie.lookup(0x0200) == 7)  // back to block 0
    }

    @Test
    func lookupAtMaxCodepointIsBoundsSafe() {
        let stage1 = Array(repeating: UInt16(0), count: 4352)
        let stage2 = Array(repeating: UInt8(99), count: 256)
        let trie = TwoStageTrie<UInt8>(stage1: stage1, stage2: stage2)
        // stage1 index = 0x10FFFF >> 8 = 0x10FF = 4351, valid (< 4352).
        #expect(trie.lookup(0x10FFFF) == 99)
    }
}
```

- [ ] **Step 2: Delete scaffold + run to verify failure**

```bash
rm Tests/UnicodePropertiesTests/ScaffoldTests.swift
swift test --filter UnicodePropertiesTests 2>&1 | tail -20
```
Expected: compile error — `TwoStageTrie` doesn't exist.

- [ ] **Step 3: Implement the trie**

Replace `Sources/UnicodeProperties/Internal/TwoStageTrie.swift`:
```swift
/// Two-stage trie for U+0000..U+10FFFF property lookups.
///
/// `stage1[codepoint >> 8]` gives a block index into stage2.
/// `stage2[(blockIndex << 8) | (codepoint & 0xFF)]` gives the value.
///
/// Duplicate 256-entry blocks in stage2 are deduplicated at codegen
/// time so identical blocks (e.g., large unassigned runs) share storage.
@usableFromInline
internal struct TwoStageTrie<Value: FixedWidthInteger> {
    @usableFromInline let stage1: [UInt16]
    @usableFromInline let stage2: [Value]

    @inlinable
    init(stage1: [UInt16], stage2: [Value]) {
        self.stage1 = stage1
        self.stage2 = stage2
    }

    @inlinable
    func lookup(_ codepoint: UInt32) -> Value {
        let block = Int(stage1[Int(codepoint >> 8)])
        return stage2[(block << 8) | Int(codepoint & 0xFF)]
    }
}
```

- [ ] **Step 4: Stub placeholder generated table**

Replace `Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` in Task 6.

@usableFromInline
internal let generalCategoryTable = TwoStageTrie<UInt8>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt8(29), count: 256)  // 29 = .unassigned raw value
)
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter UnicodePropertiesTests 2>&1 | tail -10
```
Expected: 3 TwoStageTrieTests pass.

```bash
swift test 2>&1 | tail -5
```
Expected: full suite green.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add TwoStageTrie primitive

@inlinable lookup with O(1) two-array-index access. Placeholder
generalCategoryTable allows the package to build until codegen runs.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: UCDParser

**Files:**
- Modify: `Sources/BedrockUcdGen/UCDParser.swift`
- Create: `Tests/BedrockUcdGenTests/UCDParserTests.swift`
- Delete: `Tests/BedrockUcdGenTests/ScaffoldTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/UCDParserTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct UCDParserTests {

    @Test
    func parsesSingleAsciiLine() throws {
        let input = "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;\n"
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0041)
        #expect(entries[0].last == 0x0041)
        #expect(entries[0].category == "Lu")
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
    }

    @Test
    func parsesMixedSingleAndRange() throws {
        let input = """
        0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
        4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;
        9FFF;<CJK Ideograph, Last>;Lo;0;L;;;;;N;;;;;
        AC00;<Hangul Syllable, First>;Lo;0;L;;;;;N;;;;;
        D7A3;<Hangul Syllable, Last>;Lo;0;L;;;;;N;;;;;
        """
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 3)
        #expect(entries[0].first == 0x0041)
        #expect(entries[0].last == 0x0041)
        #expect(entries[1].first == 0x4E00)
        #expect(entries[1].last == 0x9FFF)
        #expect(entries[2].first == 0xAC00)
        #expect(entries[2].last == 0xD7A3)
    }

    @Test
    func ignoresEmptyLines() throws {
        let input = """

        0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;

        """
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 1)
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0041;LATIN;Lu\n"  // only 3 fields
        do {
            _ = try UCDParser.parse(input)
            Issue.record("expected parse error on truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsUnmatchedRangeMarker() {
        let input = "4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;\n"
        // No matching Last line.
        do {
            _ = try UCDParser.parse(input)
            Issue.record("expected parse error on unmatched First")
        } catch {
            // expected
        }
    }
}
```

- [ ] **Step 2: Delete scaffold + run to verify failure**

```bash
rm Tests/BedrockUcdGenTests/ScaffoldTests.swift
swift test --filter BedrockUcdGenTests 2>&1 | tail -20
```
Expected: compile error — `UCDParser` doesn't exist.

- [ ] **Step 3: Implement UCDParser**

Replace `Sources/BedrockUcdGen/UCDParser.swift`:
```swift
public struct UCDEntry: Equatable {
    public let first: UInt32
    public let last: UInt32
    public let category: String
}

public enum UCDParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case unmatchedRangeMarker(lineNumber: Int)
}

public enum UCDParser {

    public static func parse(_ text: String) throws -> [UCDEntry] {
        var entries: [UCDEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var i = 0
        var lineNumber = 0
        while i < lines.count {
            lineNumber = i + 1
            let raw = lines[i].trimmingCharacters(in: .whitespaces)
            if raw.isEmpty {
                i += 1
                continue
            }

            let fields = raw.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 3 {
                throw UCDParseError.truncatedLine(lineNumber: lineNumber)
            }
            guard let codepoint = UInt32(fields[0], radix: 16) else {
                throw UCDParseError.invalidCodepoint(lineNumber: lineNumber,
                                                     raw: String(fields[0]))
            }
            let name = String(fields[1])
            let category = String(fields[2])

            if name.hasSuffix(", First>") {
                // Expect the next line to be the matching Last.
                guard i + 1 < lines.count else {
                    throw UCDParseError.unmatchedRangeMarker(lineNumber: lineNumber)
                }
                let nextRaw = lines[i + 1].trimmingCharacters(in: .whitespaces)
                let nextFields = nextRaw.split(separator: ";",
                                                omittingEmptySubsequences: false)
                guard nextFields.count >= 3,
                      nextFields[1].hasSuffix(", Last>") else {
                    throw UCDParseError.unmatchedRangeMarker(lineNumber: lineNumber)
                }
                guard let lastCodepoint = UInt32(nextFields[0], radix: 16) else {
                    throw UCDParseError.invalidCodepoint(lineNumber: lineNumber + 1,
                                                          raw: String(nextFields[0]))
                }
                entries.append(UCDEntry(first: codepoint,
                                         last: lastCodepoint,
                                         category: category))
                i += 2
            } else {
                entries.append(UCDEntry(first: codepoint,
                                         last: codepoint,
                                         category: category))
                i += 1
            }
        }
        return entries
    }
}
```

Helper: `trimmingCharacters(in:)` is on `String` and works with `CharacterSet`-like inputs. Since we're stdlib-only and avoiding Foundation, use `Substring` whitespace trimming via `drop(while:)`:

Replace `.trimmingCharacters(in: .whitespaces)` calls with a local helper that uses `drop(while:)` on whitespace characters. Add this private helper to the file:

```swift
private extension Substring {
    func stdlibTrimmed() -> Substring {
        var s = self.drop(while: { $0 == " " || $0 == "\t" || $0 == "\r" })
        while let last = s.last, last == " " || last == "\t" || last == "\r" {
            s = s.dropLast()
        }
        return s
    }
}
```

Then in the parser body, replace `lines[i].trimmingCharacters(in: .whitespaces)` with `String(lines[i].stdlibTrimmed())`.

- [ ] **Step 4: Run tests**

```bash
swift test --filter UCDParserTests 2>&1 | tail -10
```
Expected: 7 parser tests pass.

```bash
swift test 2>&1 | tail -5
```
Expected: full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add UCDParser

Parses UnicodeData.txt line format, handles First/Last range pairs,
emits structured UCDEntry values. Stdlib-only trimming.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: TwoStageTrieBuilder

**Files:**
- Modify: `Sources/BedrockUcdGen/TwoStageTrieBuilder.swift`
- Create: `Tests/BedrockUcdGenTests/TwoStageTrieBuilderTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/TwoStageTrieBuilderTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct TwoStageTrieBuilderTests {

    @Test
    func allZerosCompactsToOneUniqueBlock() {
        let uncompacted = Array(repeating: UInt8(0), count: 0x110000)
        let result = TwoStageTrieBuilder.build(uncompacted)
        #expect(result.stage1.count == 4352)
        #expect(result.stage2.count == 256)
        #expect(Array(Set(result.stage1)) == [0])
    }

    @Test
    func roundTripsExactly() {
        // Hand-built input: a few non-zero codepoints.
        var uncompacted = Array(repeating: UInt8(29), count: 0x110000)  // unassigned default
        uncompacted[0x0041] = 0   // Lu (A)
        uncompacted[0x0061] = 1   // Ll (a)
        uncompacted[0x4E00] = 4   // Lo (CJK)
        let result = TwoStageTrieBuilder.build(uncompacted)
        for cp in [UInt32(0x0041), 0x0061, 0x4E00, 0x10FFFF, 0xABCD] {
            let lookup = result.lookup(UInt32(cp))
            #expect(lookup == uncompacted[Int(cp)],
                    "mismatch at U+\(String(cp, radix: 16))")
        }
    }

    @Test
    func selfCheckCoversAllCodepoints() throws {
        var uncompacted = Array(repeating: UInt8(29), count: 0x110000)
        for cp in stride(from: 0, to: 0x110000, by: 257) {
            uncompacted[cp] = UInt8(cp % 30)
        }
        let result = TwoStageTrieBuilder.build(uncompacted)
        // Full round-trip
        for cp in 0..<UInt32(0x110000) {
            #expect(result.lookup(cp) == uncompacted[Int(cp)])
        }
    }

    @Test
    func dedupSharesIdenticalBlocks() {
        // Two regions of identical content should share a block.
        var uncompacted = Array(repeating: UInt8(7), count: 0x110000)
        uncompacted[0x0500] = 99  // perturb just one codepoint in block 5
        let result = TwoStageTrieBuilder.build(uncompacted)
        // Block 0 (codepoints 0x0000..0x00FF) should share with block 1 (0x0100..0x01FF) since both are all-7s.
        #expect(result.stage1[0] == result.stage1[1])
        #expect(result.stage1[0] == result.stage1[2])
        // Block 5 (0x0500..0x05FF) differs.
        #expect(result.stage1[5] != result.stage1[0])
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter TwoStageTrieBuilderTests 2>&1 | tail -10
```
Expected: compile error.

- [ ] **Step 3: Implement builder**

Replace `Sources/BedrockUcdGen/TwoStageTrieBuilder.swift`:
```swift
public struct BuiltTrie {
    public let stage1: [UInt16]
    public let stage2: [UInt8]

    public func lookup(_ codepoint: UInt32) -> UInt8 {
        let block = Int(stage1[Int(codepoint >> 8)])
        return stage2[(block << 8) | Int(codepoint & 0xFF)]
    }
}

public enum TwoStageTrieBuilder {

    /// Build a compacted two-stage trie from an uncompacted array of
    /// 0x110000 entries (one per codepoint).
    public static func build(_ uncompacted: [UInt8]) -> BuiltTrie {
        precondition(uncompacted.count == 0x110000)

        let blockCount = 0x110000 / 256   // 4352
        var stage1 = [UInt16](repeating: 0, count: blockCount)
        var stage2: [UInt8] = []
        var blockIndex: [[UInt8]: UInt16] = [:]

        for b in 0..<blockCount {
            let block = Array(uncompacted[(b * 256)..<((b + 1) * 256)])
            if let existing = blockIndex[block] {
                stage1[b] = existing
            } else {
                let idx = UInt16(stage2.count / 256)
                stage2.append(contentsOf: block)
                blockIndex[block] = idx
                stage1[b] = idx
            }
        }
        return BuiltTrie(stage1: stage1, stage2: stage2)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter TwoStageTrieBuilderTests 2>&1 | tail -10
```
Expected: 4 builder tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add TwoStageTrieBuilder

Compacts a 0x110000-entry uncompacted array into stage1/stage2 with
256-entry block deduplication via a hash map keyed on block contents.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: CodeEmitter

**Files:**
- Modify: `Sources/BedrockUcdGen/CodeEmitter.swift`
- Create: `Tests/BedrockUcdGenTests/CodeEmitterTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/CodeEmitterTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct CodeEmitterTests {

    @Test
    func headerContainsExpectedTokens() {
        let trie = BuiltTrie(
            stage1: [0, 0, 0, 0],
            stage2: [1, 2, 3]
        )
        let src = CodeEmitter.emit(trie, unicodeVersion: "16.0.0")
        #expect(src.contains("GENERATED"))
        #expect(src.contains("16.0.0"))
        #expect(src.contains("@usableFromInline"))
        #expect(src.contains("internal let generalCategoryTable"))
        #expect(src.contains("TwoStageTrie<UInt8>"))
    }

    @Test
    func includesStage1AndStage2Arrays() {
        let trie = BuiltTrie(
            stage1: [0, 0],
            stage2: [42]
        )
        let src = CodeEmitter.emit(trie, unicodeVersion: "16.0.0")
        #expect(src.contains("stage1:"))
        #expect(src.contains("stage2:"))
        #expect(src.contains("42"))
    }

    @Test
    func emitsValidSwift() {
        // Smoke: just verify the output doesn't have obviously-broken
        // syntax characters. Real validation comes from `swift build`
        // after Task 6's emission.
        let trie = BuiltTrie(
            stage1: Array(repeating: UInt16(0), count: 16),
            stage2: Array(repeating: UInt8(0), count: 256)
        )
        let src = CodeEmitter.emit(trie, unicodeVersion: "16.0.0")
        // Balanced brackets/parens — rough check.
        #expect(src.filter({ $0 == "[" }).count == src.filter({ $0 == "]" }).count)
        #expect(src.filter({ $0 == "(" }).count == src.filter({ $0 == ")" }).count)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter CodeEmitterTests 2>&1 | tail -10
```
Expected: compile error.

- [ ] **Step 3: Implement CodeEmitter**

Replace `Sources/BedrockUcdGen/CodeEmitter.swift`:
```swift
public enum CodeEmitter {

    public static func emit(_ trie: BuiltTrie, unicodeVersion: String) -> String {
        var out = ""
        out += "// GENERATED by `swift run bedrock-ucd-gen`. Do not edit by hand.\n"
        out += "// Source: Sources/UnicodeProperties/UCD/UnicodeData.txt "
        out += "(Unicode \(unicodeVersion))\n"
        out += "\n"
        out += "@usableFromInline\n"
        out += "internal let generalCategoryTable = TwoStageTrie<UInt8>(\n"
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
        // 16 values per line for readability.
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

- [ ] **Step 4: Run tests**

```bash
swift test --filter CodeEmitterTests 2>&1 | tail -10
```
Expected: 3 emitter tests pass.

```bash
swift test 2>&1 | tail -5
```
Expected: full suite green.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add CodeEmitter

Formats a BuiltTrie as a Swift source file containing the literal
stage1/stage2 arrays. 16 values per line.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Wire up codegen and run it

**Files:**
- Modify: `Sources/bedrock-ucd-gen/main.swift`
- Modify: `Sources/BedrockUcdGen/UCDParser.swift` (add `expand(_:) -> [UInt8]` to convert UCDEntry list to uncompacted array)
- Modify: `Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift` (overwritten by codegen)

This is the integration task. The codegen tool wires parser → builder → emitter, runs the self-check, and writes the generated table file. After running, the placeholder generated file is replaced with the real one.

- [ ] **Step 1: Add category-abbreviation → UInt8 mapping**

Append to `Sources/BedrockUcdGen/UCDParser.swift`:
```swift
public enum GeneralCategoryCode {
    /// Map UCD category abbreviation to the UnicodeProperties.GeneralCategory raw value.
    public static func rawValue(for abbreviation: String) throws -> UInt8 {
        switch abbreviation {
        case "Lu": return 0
        case "Ll": return 1
        case "Lt": return 2
        case "Lm": return 3
        case "Lo": return 4
        case "Mn": return 5
        case "Mc": return 6
        case "Me": return 7
        case "Nd": return 8
        case "Nl": return 9
        case "No": return 10
        case "Pc": return 11
        case "Pd": return 12
        case "Ps": return 13
        case "Pe": return 14
        case "Pi": return 15
        case "Pf": return 16
        case "Po": return 17
        case "Sm": return 18
        case "Sc": return 19
        case "Sk": return 20
        case "So": return 21
        case "Zs": return 22
        case "Zl": return 23
        case "Zp": return 24
        case "Cc": return 25
        case "Cf": return 26
        case "Cs": return 27
        case "Co": return 28
        case "Cn": return 29
        default:
            throw UCDParseError.invalidCodepoint(lineNumber: -1, raw: abbreviation)
        }
    }
}

public extension Array where Element == UCDEntry {
    /// Expand a list of UCDEntries into a 0x110000-element uncompacted
    /// array of general-category raw values. Codepoints absent from
    /// the input default to .unassigned (raw 29).
    func expandToUncompacted() throws -> [UInt8] {
        var out = [UInt8](repeating: 29, count: 0x110000)  // .unassigned default
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

- [ ] **Step 2: Implement main**

Replace `Sources/bedrock-ucd-gen/main.swift`:
```swift
import BedrockUcdGen

// File paths are relative to the repo root.
let ucdPath = "Sources/UnicodeProperties/UCD/UnicodeData.txt"
let outputPath = "Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift"
let unicodeVersion = "16.0.0"

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

let uncompacted: [UInt8]
do {
    uncompacted = try entries.expandToUncompacted()
} catch {
    print("Expansion error: \(error)")
    exit(1)
}

let trie = TwoStageTrieBuilder.build(uncompacted)
print("Built two-stage trie: stage1=\(trie.stage1.count) entries, stage2=\(trie.stage2.count) entries.")

// Self-check: every codepoint round-trips.
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
    print("Self-check FAILED: \(mismatches) mismatches.")
    exit(1)
}
print("Self-check OK: 1114112 codepoints round-trip.")

let src = CodeEmitter.emit(trie, unicodeVersion: unicodeVersion)
do {
    try src.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("Wrote \(outputPath) (\(src.utf8.count) bytes).")
} catch {
    print("Write error: \(error)")
    exit(1)
}
```

**Note:** `String(contentsOfFile:encoding:)` and `String.write(toFile:atomically:encoding:)` are Foundation methods. We need stdlib-only file IO. The cleanest stdlib-only approach:

```swift
import Bytes
```

…and use a tiny ad-hoc file reader. **But:** `bedrock-ucd-gen` is allowed to depend on whatever helps — it's a build-time tool, not the library. The constraint of stdlib-only applies most strictly to the runtime library.

That said, the cleanest path is to use `FileHandle` from Foundation here. Bedrock's stdlib-only stance is for the runtime library, not for build-time tooling that runs on the developer's machine. **The codegen tool may import Foundation.** Update `Package.swift` to import Foundation in `bedrock-ucd-gen` if necessary, or use the stdlib-bridged file APIs via Glibc/Darwin C interop.

Pick the simplest path: use the `import Foundation`-flavored `String(contentsOfFile:)` and `String.write(toFile:)`. The codegen tool is host-side only. Document this in the spec follow-up if needed.

If you want to keep it strictly stdlib-only, use `fopen` / `fread` / `fclose` via Darwin/Glibc with `#if canImport(Darwin) import Darwin #elseif canImport(Glibc) import Glibc #endif`. More work but no Foundation footprint.

For v1, **use Foundation in the codegen tool**. Add `import Foundation` to `main.swift`.

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen
```

Expected output:
```
Reading Sources/UnicodeProperties/UCD/UnicodeData.txt ...
Parsed N entries.
Built two-stage trie: stage1=4352 entries, stage2=<some N>×256 entries.
Self-check OK: 1114112 codepoints round-trip.
Wrote Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift (~50-100 KB).
```

If self-check fails, the trie builder or expansion has a bug. STOP and investigate before committing.

- [ ] **Step 4: Verify the generated file compiles and tests pass**

```bash
swift build 2>&1 | tail -5
swift test 2>&1 | tail -5
```
Expected: builds clean; full suite green. The placeholder TwoStageTrie tests should still pass against the real generated table (they don't depend on specific codepoint values, only trie shape).

- [ ] **Step 5: Spot-check the generated file**

```bash
head -10 Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift
wc -l Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift
wc -c Sources/UnicodeProperties/Generated/GeneralCategoryTable.swift
```
Expected: starts with the GENERATED banner; total bytes 50-150 KB.

- [ ] **Step 6: Commit**

```bash
git add Sources/BedrockUcdGen Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): wire up codegen and generate table

bedrock-ucd-gen main.swift reads UnicodeData.txt, parses, expands to
uncompacted array, builds and self-checks the trie, emits the
generated Swift source. Ran successfully against Unicode 16.0.0;
all 1114112 codepoints round-trip.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: UnicodeProperties public API

**Files:**
- Create: `Sources/UnicodeProperties/GeneralCategory.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/GeneralCategoryTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/UnicodePropertiesTests/GeneralCategoryTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct GeneralCategoryTests {

    private func cat(_ scalar: Unicode.Scalar) -> UnicodeProperties.GeneralCategory {
        UnicodeProperties.generalCategory(of: scalar)
    }

    @Test
    func asciiUppercaseLetter() {
        #expect(cat("A") == .uppercaseLetter)
        #expect(cat("Z") == .uppercaseLetter)
    }

    @Test
    func asciiLowercaseLetter() {
        #expect(cat("a") == .lowercaseLetter)
        #expect(cat("z") == .lowercaseLetter)
    }

    @Test
    func asciiDigit() {
        #expect(cat("0") == .decimalNumber)
        #expect(cat("9") == .decimalNumber)
    }

    @Test
    func asciiPunctuation() {
        #expect(cat("!") == .otherPunctuation)
        #expect(cat(",") == .otherPunctuation)
    }

    @Test
    func asciiSpace() {
        #expect(cat(" ") == .spaceSeparator)
    }

    @Test
    func asciiControl() {
        #expect(cat("\u{0000}") == .control)
        #expect(cat("\u{0009}") == .control)  // tab
        #expect(cat("\u{007F}") == .control)
    }

    @Test
    func latin1Uppercase() {
        #expect(cat("\u{00C0}") == .uppercaseLetter)  // À
    }

    @Test
    func titlecaseLetter() {
        #expect(cat("\u{01C5}") == .titlecaseLetter)  // ǅ
    }

    @Test
    func combiningMark() {
        #expect(cat("\u{0301}") == .nonspacingMark)  // combining acute
    }

    @Test
    func cjkIdeograph() {
        #expect(cat("\u{6F22}") == .otherLetter)  // 漢
    }

    @Test
    func hangulSyllable() {
        #expect(cat("\u{D55C}") == .otherLetter)  // 한
    }

    @Test
    func mathematicalSymbol() {
        #expect(cat("\u{2211}") == .mathSymbol)  // ∑
        #expect(cat("+") == .mathSymbol)
    }

    @Test
    func currencySymbol() {
        #expect(cat("$") == .currencySymbol)
        #expect(cat("\u{20AC}") == .currencySymbol)  // €
    }

    @Test
    func emoji() {
        #expect(cat("\u{1F600}") == .otherSymbol)  // 😀
    }

    @Test
    func privateUse() {
        #expect(cat(Unicode.Scalar(0xE000)!) == .privateUse)
    }

    @Test
    func formatChar() {
        #expect(cat(Unicode.Scalar(0x200B)!) == .format)  // ZWSP
    }

    @Test
    func unicodeVersionConstant() {
        #expect(UnicodeProperties.unicodeVersion == "16.0.0")
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter GeneralCategoryTests 2>&1 | tail -10
```
Expected: compile error.

- [ ] **Step 3: Implement GeneralCategory**

Create `Sources/UnicodeProperties/GeneralCategory.swift`:
```swift
extension UnicodeProperties {

    /// Unicode general category (UnicodeData.txt field 3, UAX #44 table 12).
    public enum GeneralCategory: UInt8, Sendable, Hashable, CaseIterable {
        case uppercaseLetter        = 0   // Lu
        case lowercaseLetter        = 1   // Ll
        case titlecaseLetter        = 2   // Lt
        case modifierLetter         = 3   // Lm
        case otherLetter            = 4   // Lo
        case nonspacingMark         = 5   // Mn
        case spacingMark            = 6   // Mc
        case enclosingMark          = 7   // Me
        case decimalNumber          = 8   // Nd
        case letterNumber           = 9   // Nl
        case otherNumber            = 10  // No
        case connectorPunctuation   = 11  // Pc
        case dashPunctuation        = 12  // Pd
        case openPunctuation        = 13  // Ps
        case closePunctuation       = 14  // Pe
        case initialPunctuation     = 15  // Pi
        case finalPunctuation       = 16  // Pf
        case otherPunctuation       = 17  // Po
        case mathSymbol             = 18  // Sm
        case currencySymbol         = 19  // Sc
        case modifierSymbol         = 20  // Sk
        case otherSymbol            = 21  // So
        case spaceSeparator         = 22  // Zs
        case lineSeparator          = 23  // Zl
        case paragraphSeparator     = 24  // Zp
        case control                = 25  // Cc
        case format                 = 26  // Cf
        case surrogate              = 27  // Cs
        case privateUse             = 28  // Co
        case unassigned             = 29  // Cn
    }
}
```

- [ ] **Step 4: Implement public API**

Replace `Sources/UnicodeProperties/UnicodeProperties.swift`:
```swift
public enum UnicodeProperties {

    /// The Unicode version these tables were generated from.
    public static let unicodeVersion: String = "16.0.0"

    /// O(1) general-category lookup. Returns `.unassigned` for codepoints
    /// not assigned in Unicode 16.0.
    @inlinable
    public static func generalCategory(of scalar: Unicode.Scalar) -> GeneralCategory {
        let raw = generalCategoryTable.lookup(scalar.value)
        // Raw value 29 == .unassigned; values 0..29 are all valid.
        return GeneralCategory(rawValue: raw) ?? .unassigned
    }

    /// Any L* category (uppercase, lowercase, titlecase, modifier, other).
    @inlinable
    public static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .uppercaseLetter || c == .lowercaseLetter
            || c == .titlecaseLetter || c == .modifierLetter || c == .otherLetter
    }

    /// Any N* category.
    @inlinable
    public static func isNumber(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .decimalNumber || c == .letterNumber || c == .otherNumber
    }

    /// Any M* category.
    @inlinable
    public static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .nonspacingMark || c == .spacingMark || c == .enclosingMark
    }

    /// Any P* category.
    @inlinable
    public static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .connectorPunctuation || c == .dashPunctuation
            || c == .openPunctuation || c == .closePunctuation
            || c == .initialPunctuation || c == .finalPunctuation
            || c == .otherPunctuation
    }

    /// Any S* category.
    @inlinable
    public static func isSymbol(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .mathSymbol || c == .currencySymbol
            || c == .modifierSymbol || c == .otherSymbol
    }

    /// Any Z* category.
    @inlinable
    public static func isSeparator(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .spaceSeparator || c == .lineSeparator || c == .paragraphSeparator
    }

    /// Any C* category.
    @inlinable
    public static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .control || c == .format || c == .surrogate
            || c == .privateUse || c == .unassigned
    }
}
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter UnicodePropertiesTests 2>&1 | tail -10
swift test 2>&1 | tail -5
```
Expected: 17 GeneralCategoryTests + earlier 3 TwoStageTrieTests pass; full suite green.

If a spot-check fails (e.g., `cat("$")` returns something unexpected), the codegen has a bug or the expected category in the test is wrong. Investigate by looking at the corresponding line in `UnicodeData.txt`.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add public API

GeneralCategory enum (30 cases), generalCategory(of:) O(1) lookup,
seven major-category helpers (isLetter/isNumber/isMark/isPunctuation/
isSymbol/isSeparator/isControl), unicodeVersion constant.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Boundary, ranged-entry, helper, and exhaustive tests

**Files:**
- Create: `Tests/UnicodePropertiesTests/MajorCategoryHelperTests.swift`
- Create: `Tests/UnicodePropertiesTests/BoundaryTests.swift`
- Create: `Tests/UnicodePropertiesTests/RangedEntryTests.swift`
- Create: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`

- [ ] **Step 1: Major-category helper tests**

Create `Tests/UnicodePropertiesTests/MajorCategoryHelperTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct MajorCategoryHelperTests {

    @Test
    func isLetter() {
        #expect(UnicodeProperties.isLetter("A"))
        #expect(UnicodeProperties.isLetter("z"))
        #expect(UnicodeProperties.isLetter("\u{6F22}"))   // 漢
        #expect(UnicodeProperties.isLetter("5") == false)
        #expect(UnicodeProperties.isLetter("!") == false)
    }

    @Test
    func isNumber() {
        #expect(UnicodeProperties.isNumber("5"))
        #expect(UnicodeProperties.isNumber("\u{2163}"))  // Ⅳ (ROMAN NUMERAL FOUR, Nl)
        #expect(UnicodeProperties.isNumber("A") == false)
    }

    @Test
    func isMark() {
        #expect(UnicodeProperties.isMark("\u{0301}"))    // combining acute
        #expect(UnicodeProperties.isMark("A") == false)
    }

    @Test
    func isPunctuation() {
        #expect(UnicodeProperties.isPunctuation("!"))
        #expect(UnicodeProperties.isPunctuation(","))
        #expect(UnicodeProperties.isPunctuation("("))
        #expect(UnicodeProperties.isPunctuation("A") == false)
    }

    @Test
    func isSymbol() {
        #expect(UnicodeProperties.isSymbol("\u{2211}"))  // ∑
        #expect(UnicodeProperties.isSymbol("$"))
        #expect(UnicodeProperties.isSymbol("A") == false)
    }

    @Test
    func isSeparator() {
        #expect(UnicodeProperties.isSeparator(" "))
        #expect(UnicodeProperties.isSeparator("\n") == false)  // newline is Cc, not Z
    }

    @Test
    func isControl() {
        #expect(UnicodeProperties.isControl("\t"))
        #expect(UnicodeProperties.isControl("\n"))
        #expect(UnicodeProperties.isControl("A") == false)
    }
}
```

- [ ] **Step 2: Boundary tests**

Create `Tests/UnicodePropertiesTests/BoundaryTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct BoundaryTests {

    private func cat(_ cp: UInt32) -> UnicodeProperties.GeneralCategory {
        UnicodeProperties.generalCategory(of: Unicode.Scalar(cp)!)
    }

    @Test
    func lastAsciiIsControl() {
        #expect(cat(0x007F) == .control)
    }

    @Test
    func firstLatin1SupplementIsControl() {
        #expect(cat(0x0080) == .control)
    }

    @Test
    func bmpPuaStartAndEnd() {
        #expect(cat(0xE000) == .privateUse)
        #expect(cat(0xF8FF) == .privateUse)
    }

    @Test
    func lastValidScalarIsPrivateUse() {
        #expect(cat(0x10FFFD) == .privateUse)
    }

    @Test
    func justBeforeCjkRangeIsNotLetter() {
        // U+4DFF is the codepoint just before U+4E00 (CJK Ideograph First).
        // Per UCD it should not be a letter.
        let c = cat(0x4DFF)
        #expect(c != .otherLetter)
    }

    @Test
    func cjkRangeFirstAndLast() {
        #expect(cat(0x4E00) == .otherLetter)
        #expect(cat(0x9FFF) == .otherLetter)
    }
}
```

- [ ] **Step 3: Ranged-entry tests**

Create `Tests/UnicodePropertiesTests/RangedEntryTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct RangedEntryTests {

    private func cat(_ cp: UInt32) -> UnicodeProperties.GeneralCategory {
        UnicodeProperties.generalCategory(of: Unicode.Scalar(cp)!)
    }

    @Test
    func cjkIdeographRange() {
        // Endpoints + midpoint
        #expect(cat(0x4E00) == .otherLetter)
        #expect(cat(0x5000) == .otherLetter)
        #expect(cat(0x9FFF) == .otherLetter)
    }

    @Test
    func hangulSyllableRange() {
        #expect(cat(0xAC00) == .otherLetter)
        #expect(cat(0xD55C) == .otherLetter)
        #expect(cat(0xD7A3) == .otherLetter)
    }

    @Test
    func tangutIdeographRange() {
        #expect(cat(0x17000) == .otherLetter)
        #expect(cat(0x187F7) == .otherLetter)
    }

    @Test
    func plane15PrivateUseRange() {
        #expect(cat(0xF0000) == .privateUse)
        #expect(cat(0xFFFFD) == .privateUse)
    }

    @Test
    func plane16PrivateUseRange() {
        #expect(cat(0x100000) == .privateUse)
        #expect(cat(0x10FFFD) == .privateUse)
    }
}
```

- [ ] **Step 4: Exhaustive test**

Create `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct ExhaustiveTests {

    @Test
    func everyCodepointLookupCompletesAndReturnsValidValue() {
        for cp: UInt32 in 0 ..< 0x110000 {
            guard let scalar = Unicode.Scalar(cp) else { continue }
            let c = UnicodeProperties.generalCategory(of: scalar)
            // Raw value must be in 0...29.
            #expect(c.rawValue <= 29,
                    "out-of-range raw value at U+\(String(cp, radix: 16))")
        }
    }
}
```

- [ ] **Step 5: Run all UnicodeProperties tests**

```bash
swift test --filter UnicodePropertiesTests 2>&1 | tail -10
swift test 2>&1 | tail -5
```
Expected: all tests pass; full suite green. Exhaustive test should complete in well under a second.

If any test fails:
- Helper/Boundary/Ranged: real codegen or test-data bug. If the test asserts something the UCD says, the codegen has a bug; investigate via `grep "<codepoint>" UnicodeData.txt`.
- Exhaustive: the trie has a malformed entry; investigate via the failing codepoint.

DO NOT alter the codegen output to make tests pass — that's overwritten on the next run. Fix the codegen instead.

- [ ] **Step 6: Commit**

```bash
git add Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
test(unicode-properties): boundary, ranged, helper, exhaustive

Major-category helpers; boundary codepoints (ASCII/Latin-1/PUA/last
scalar); compressed ranges (CJK/Hangul/Tangut/Plane-15-16 PUA);
exhaustive 1.1M-codepoint sanity check.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Coverage verification + Layer 2 doc update

**Files:**
- Possibly: tests for coverage fill-in
- Modify: `layers/layer-02-text-unicode.md`

- [ ] **Step 1: Run full suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass, zero warnings.

- [ ] **Step 2: Generate coverage**

```bash
swift test --enable-code-coverage 2>&1 | tail -3
PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'BedrockPackageTests.xctest' -type d | head -1)/Contents/MacOS/BedrockPackageTests
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
  -ignore-filename-regex='Tests|\.build|Generated' \
  Sources/UnicodeProperties/UnicodeProperties.swift \
  Sources/UnicodeProperties/GeneralCategory.swift \
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/UCDParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```

Expected: each file ≥ 90% line coverage. Generated table file (`Generated/GeneralCategoryTable.swift`) is excluded — it's pure data, no logic to cover.

- [ ] **Step 3: Address gaps**

If any file falls below 90%, identify uncovered lines via `xcrun llvm-cov show` and add targeted tests. For precondition-message autoclosure artifacts: drop the message string (same pattern used in COBS and TaggedPointer).

- [ ] **Step 4: Update Layer 2 doc**

Edit `layers/layer-02-text-unicode.md`. Add a "Status" section above the Libraries table noting that UnicodeProperties is the first Layer 2 module shipped.

Find the section beginning `Swift's String is Unicode-correct...` and insert immediately AFTER that paragraph:

```markdown
> **Status:** shipping modules:
> - `Sources/UnicodeProperties/` — UCD-derived general-category lookup with O(1) two-stage trie; codegen tool `bedrock-ucd-gen` ([design](../docs/superpowers/specs/2026-05-19-unicode-properties-design.md), [plan](../docs/superpowers/plans/2026-05-19-unicode-properties-module.md)). Unicode 16.0.0.
>
> Subsequent sub-projects (Layer 2.2–2.8): extended properties, normalization (NFC/NFD/NFKC/NFKD), segmentation (UAX #29), case mapping, identifier classification (UAX #31), bidi (UAX #9), ASCII helpers.
```

- [ ] **Step 5: Commit**

```bash
git add layers/layer-02-text-unicode.md
git commit -m "$(cat <<'EOF'
docs(layer-2): mark UnicodeProperties module shipped

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** Every API surface item (`generalCategory(of:)`, 7 major-category helpers, `unicodeVersion`, `GeneralCategory` enum, internal `TwoStageTrie`, codegen tool) has a task. Every test category in the spec (spot-checks, helpers, boundary, ranged, exhaustive, parser, builder, emitter) is covered.
- **Codegen / library ordering:** T1 scaffolds both. T2 adds the runtime trie + placeholder generated file (so swift build always works). T3-T5 build the codegen pipeline. T6 runs codegen, replacing the placeholder. T7 adds the public API consuming the now-real table. T8 adds the remaining test suites. T9 verifies coverage and docs.
- **No placeholders in tasks:** Every step shows the exact code or command.
- **Type consistency:** `UnicodeProperties.GeneralCategory`, raw values 0..29, helpers' L*/N*/M*/P*/S*/Z*/C* groupings, internal `TwoStageTrie<UInt8>` are all consistent across tasks.
- **Foundation usage in codegen:** Task 6 deliberately allows `import Foundation` in the executable's `main.swift` for `String(contentsOfFile:)` and `String.write(toFile:)`. This is build-time tooling only, runs on the developer's machine; the library remains stdlib-only.
- **Self-check at codegen time:** Task 6 includes the round-trip self-check that aborts before emitting if any codepoint mismatches. Catches builder bugs at codegen time, not test time.
- **Generated file is not under TDD:** Task 6 produces a ~50-150 KB Swift file by running the tool. Correctness comes from the codegen-time self-check + Task 8's exhaustive test. The generated file should be committed, not hand-edited.

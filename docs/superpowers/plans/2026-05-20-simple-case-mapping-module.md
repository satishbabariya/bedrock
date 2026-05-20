# Simple Case Mapping Implementation Plan (Layer 2.3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `simpleUppercase`/`simpleLowercase`/`simpleTitlecase` (of:) to `UnicodeProperties` per the spec at `docs/superpowers/specs/2026-05-20-simple-case-mapping-design.md`. Generalize the trie/builder/emitter over the value type along the way.

**Architecture:** Extend `UCDEntry` with three `UInt32` mapping fields. Generalize `BuiltTrie`, `TwoStageTrieBuilder.build`, `CodeEmitter.emit` over `Value: FixedWidthInteger & Sendable`. Add three expansion helpers (non-throwing). Extend `main.swift` with a second loop for `UInt32` properties. Three new generated table files. One new public file with three `@inlinable` entry points.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/BedrockUcdGen/UCDParser.swift` — extend `UCDEntry`, extend parser, add three new expansion helpers.
- `Sources/BedrockUcdGen/TwoStageTrieBuilder.swift` — generalize `BuiltTrie` and `build` over `Value`.
- `Sources/BedrockUcdGen/CodeEmitter.swift` — generalize `emit` over `Value`, add `valueTypeName:` parameter.
- `Sources/bedrock-ucd-gen/main.swift` — add a second loop for `UInt32` properties; pass `valueTypeName` everywhere.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — three new entry points + a small file-shuffle (see Task 5).
- `Tests/BedrockUcdGenTests/UCDParserTests.swift` — one new test for case-field parsing.
- `Tests/BedrockUcdGenTests/CodeEmitterTests.swift` — update existing call sites for new `valueTypeName:`.
- `Tests/BedrockUcdGenTests/TwoStageTrieBuilderTests.swift` — one new test for `UInt32` instantiation.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — sweep the three new entry points.

**Creations:**
- `Sources/UnicodeProperties/SimpleCaseMapping.swift`
- `Sources/UnicodeProperties/Generated/SimpleUppercaseTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/SimpleLowercaseTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/SimpleTitlecaseTable.swift` (placeholder, then real)
- `Tests/UnicodePropertiesTests/SimpleCaseMappingTests.swift`
- `Tests/BedrockUcdGenTests/ExpandSimpleCaseTests.swift`

---

## Task 1: Extend UCDEntry and parser for fields 12/13/14

**Files:**
- Modify: `Sources/BedrockUcdGen/UCDParser.swift`
- Modify: `Tests/BedrockUcdGenTests/UCDParserTests.swift`

- [ ] **Step 1: Write/update failing tests**

In `Tests/BedrockUcdGenTests/UCDParserTests.swift`, edit `parsesSingleAsciiLine` to additionally assert the new fields. The input is the line for U+0041:
```
0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
```
Fields 12/13/14 are at positions… let's count semicolons: 0041(0), name(1), Lu(2), 0(3), L(4), ""(5), ""(6), ""(7), ""(8), N(9), ""(10), ""(11), ""(12), 0061(13), ""(14). So field 12 is empty, field 13 is `0061`, field 14 is empty.

Add to `parsesSingleAsciiLine`:
```swift
    #expect(entries[0].simpleUppercase == 0)
    #expect(entries[0].simpleLowercase == 0x0061)
    #expect(entries[0].simpleTitlecase == 0)
```

Add a new test after `rejectsNonNumericCCC`:
```swift
    @Test
    func parsesTitlecaseLetter() throws {
        // U+01C5 LATIN CAPITAL LETTER D WITH SMALL LETTER Z WITH CARON (titlecase)
        // upper=01C4, lower=01C6, title=01C5 (identity in field 14? Actually UCD has 01C5 there)
        let input = "01C5;LATIN CAPITAL LETTER D WITH SMALL LETTER Z WITH CARON;Lt;0;L;<compat> 0044 017E;;;;N;LATIN LETTER CAPITAL D SMALL Z HACEK;;01C4;01C6;01C5\n"
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].simpleUppercase == 0x01C4)
        #expect(entries[0].simpleLowercase == 0x01C6)
        #expect(entries[0].simpleTitlecase == 0x01C5)
    }
```

Note: U+01C5's UCD line has 15 fields. The titlecase field (14) for this entry is `01C5` (i.e., identity is *explicitly* stored, not empty). Our convention treats `0` as identity; storing the explicit value here is harmless because the lookup returns `01C5` which equals the input. The test just confirms the parser reads field 14 correctly.

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter UCDParserTests 2>&1 | tail -10
```
Expected: compile error — `simpleUppercase`, `simpleLowercase`, `simpleTitlecase` don't exist on `UCDEntry`.

- [ ] **Step 3: Update `UCDEntry` and parser**

In `Sources/BedrockUcdGen/UCDParser.swift`, replace the struct:
```swift
public struct UCDEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let category: String
    public let canonicalCombiningClass: UInt8
    public let bidiClass: String
    public let simpleUppercase: UInt32
    public let simpleLowercase: UInt32
    public let simpleTitlecase: UInt32

    public init(first: UInt32,
                last: UInt32,
                category: String,
                canonicalCombiningClass: UInt8 = 0,
                bidiClass: String = "L",
                simpleUppercase: UInt32 = 0,
                simpleLowercase: UInt32 = 0,
                simpleTitlecase: UInt32 = 0) {
        self.first = first
        self.last = last
        self.category = category
        self.canonicalCombiningClass = canonicalCombiningClass
        self.bidiClass = bidiClass
        self.simpleUppercase = simpleUppercase
        self.simpleLowercase = simpleLowercase
        self.simpleTitlecase = simpleTitlecase
    }
}
```

In the parser body, after extracting `bidi`, add:
```swift
            let upper = fields[12].isEmpty ? 0 : (UInt32(fields[12], radix: 16) ?? 0)
            let lower = fields[13].isEmpty ? 0 : (UInt32(fields[13], radix: 16) ?? 0)
            let title = fields[14].isEmpty ? 0 : (UInt32(fields[14], radix: 16) ?? 0)
```

Then thread `upper`/`lower`/`title` into both `entries.append(UCDEntry(...))` call sites in the parser. Add named arguments:
```swift
                entries.append(UCDEntry(first: codepoint,
                                         last: lastCodepoint,
                                         category: category,
                                         canonicalCombiningClass: ccc,
                                         bidiClass: bidi,
                                         simpleUppercase: upper,
                                         simpleLowercase: lower,
                                         simpleTitlecase: title))
```
(and likewise for the single-line branch).

- [ ] **Step 4: Run all tests**

```bash
swift test --filter UCDParserTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: parser tests pass; full suite green at the prior count (598) plus the new test (599).

If other tests break because they relied on `UCDEntry`'s old shape, the default-parameter init should let them keep compiling. Investigate any breakage; don't silently patch unrelated tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): extend UCDEntry and parser for case mappings

Three new UInt32 fields on UCDEntry (simpleUppercase/Lowercase/
Titlecase). 0 means identity (no mapping). Defaults provided so
synthetic test inputs needn't specify them. Parser reads UCD fields
12/13/14 as hex codepoints; empty fields stay at 0.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Generalize BuiltTrie and TwoStageTrieBuilder over Value

**Files:**
- Modify: `Sources/BedrockUcdGen/TwoStageTrieBuilder.swift`
- Modify: `Tests/BedrockUcdGenTests/TwoStageTrieBuilderTests.swift`

- [ ] **Step 1: Add the failing `UInt32` test**

Append to the `TwoStageTrieBuilderTests` @Suite struct:
```swift
    @Test
    func builderHandlesUInt32() {
        var uncompacted = [UInt32](repeating: 0, count: 0x110000)
        uncompacted[0x0041] = 0x0061
        uncompacted[0x0061] = 0x0041
        let result = TwoStageTrieBuilder.build(uncompacted)
        #expect(result.lookup(0x0041) == 0x0061)
        #expect(result.lookup(0x0061) == 0x0041)
        #expect(result.lookup(0x0042) == 0)
        #expect(result.lookup(0x10FFFF) == 0)
    }
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter TwoStageTrieBuilderTests 2>&1 | tail -10
```
Expected: compile error — `TwoStageTrieBuilder.build` infers `[UInt8]` from its only signature and rejects `[UInt32]`.

- [ ] **Step 3: Generalize `BuiltTrie` and `build`**

Replace `Sources/BedrockUcdGen/TwoStageTrieBuilder.swift`:
```swift
public struct BuiltTrie<Value: FixedWidthInteger & Sendable>: Sendable {
    public let stage1: [UInt16]
    public let stage2: [Value]

    public init(stage1: [UInt16], stage2: [Value]) {
        self.stage1 = stage1
        self.stage2 = stage2
    }

    public func lookup(_ codepoint: UInt32) -> Value {
        let block = Int(stage1[Int(codepoint >> 8)])
        return stage2[(block << 8) | Int(codepoint & 0xFF)]
    }
}

public enum TwoStageTrieBuilder {

    /// Build a compacted two-stage trie from an uncompacted array of
    /// 0x110000 entries (one per codepoint).
    public static func build<Value: FixedWidthInteger & Sendable>(
        _ uncompacted: [Value]
    ) -> BuiltTrie<Value> {
        precondition(uncompacted.count == 0x110000)

        let blockCount = 0x110000 / 256
        var stage1 = [UInt16](repeating: 0, count: blockCount)
        var stage2: [Value] = []
        var blockIndex: [[Value]: UInt16] = [:]

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
swift test 2>&1 | tail -3
```
Expected: existing `UInt8` builder tests + the new `UInt32` test all pass; full suite green at 600.

If `main.swift` or `CodeEmitter.swift` won't compile because they reference `BuiltTrie` without a type parameter, leave that for the next task (we'll generalize `CodeEmitter` in Task 3). In the meantime, the existing `BuiltTrie` usages should still infer `BuiltTrie<UInt8>` automatically from the `[UInt8]` arguments, so existing code likely compiles unchanged.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
refactor(bedrock-ucd-gen): generalize BuiltTrie and build over Value

BuiltTrie<Value: FixedWidthInteger & Sendable>; build infers Value
from its argument. Existing UInt8 call sites continue to work
unchanged via Swift's type inference. New test verifies UInt32
instantiation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Generalize CodeEmitter + add valueTypeName

**Files:**
- Modify: `Sources/BedrockUcdGen/CodeEmitter.swift`
- Modify: `Tests/BedrockUcdGenTests/CodeEmitterTests.swift`
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Update existing emitter tests**

In `Tests/BedrockUcdGenTests/CodeEmitterTests.swift`, every `CodeEmitter.emit(...)` call currently passes `unicodeVersion: ..., globalName: ...`. Add `valueTypeName: "UInt8"` to each. There are 4 call sites (one per @Test function).

Add one new test:
```swift
    @Test
    func usesProvidedValueTypeName() {
        var uncompacted = [UInt32](repeating: 0, count: 0x110000)
        uncompacted[0x0041] = 0x0061
        let trie = TwoStageTrieBuilder.build(uncompacted)
        let src = CodeEmitter.emit(trie,
                                    unicodeVersion: "16.0.0",
                                    globalName: "uint32Table",
                                    valueTypeName: "UInt32")
        #expect(src.contains("TwoStageTrie<UInt32>"))
        #expect(src.contains("TwoStageTrie<UInt8>") == false)
    }
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter CodeEmitterTests 2>&1 | tail -5
```
Expected: compile error — `emit` signature mismatch.

- [ ] **Step 3: Generalize `CodeEmitter.emit`**

Replace `Sources/BedrockUcdGen/CodeEmitter.swift`:
```swift
public enum CodeEmitter {

    public static func emit<Value: FixedWidthInteger & Sendable>(
        _ trie: BuiltTrie<Value>,
        unicodeVersion: String,
        globalName: String,
        valueTypeName: String
    ) -> String {
        var out = ""
        out += "// GENERATED by `swift run bedrock-ucd-gen`. Do not edit by hand.\n"
        out += "// Source: Sources/UnicodeProperties/UCD/UnicodeData.txt "
        out += "(Unicode \(unicodeVersion))\n"
        out += "\n"
        out += "@usableFromInline\n"
        out += "internal let \(globalName) = TwoStageTrie<\(valueTypeName)>(\n"
        out += "    stage1: [\n"
        out += formatArray(trie.stage1.map { UInt($0) }, indent: "        ")
        out += "\n    ],\n"
        out += "    stage2: [\n"
        out += formatArray(trie.stage2.map { UInt(truncatingIfNeeded: $0) }, indent: "        ")
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

The `UInt(truncatingIfNeeded: $0)` works for any `FixedWidthInteger` and preserves the bit pattern. Since we're dealing only with unsigned values (UInt8, UInt32, etc.), the printed decimal value is what we want.

- [ ] **Step 4: Update main.swift to pass valueTypeName**

In `Sources/bedrock-ucd-gen/main.swift`, find the existing `CodeEmitter.emit(...)` call inside the loop. Add `valueTypeName: "UInt8"` to it. The current invocation looks like:
```swift
let src = CodeEmitter.emit(trie, unicodeVersion: unicodeVersion, globalName: globalName)
```
Change to:
```swift
let src = CodeEmitter.emit(trie,
                            unicodeVersion: unicodeVersion,
                            globalName: globalName,
                            valueTypeName: "UInt8")
```

- [ ] **Step 5: Run tests and codegen smoke test**

```bash
swift build 2>&1 | tail -3
swift test --filter CodeEmitterTests 2>&1 | tail -5
swift test 2>&1 | tail -3
swift run bedrock-ucd-gen 2>&1 | tail -10
```
Expected: builds clean; 5 CodeEmitter tests pass (4 updated + 1 new); full suite green at 601; codegen runs successfully and regenerates the three existing UInt8 tables.

- [ ] **Step 6: Verify the regenerated tables are unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: either no diff at all (tables were already in their canonical form), or a small whitespace-only diff. If there's a meaningful content change, STOP — something in the generic refactor changed the output unexpectedly.

If there's no diff, no `git add` needed. If there's a trivial diff, include the regenerated files in the commit below.

- [ ] **Step 7: Commit**

```bash
git add Sources/BedrockUcdGen Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
refactor(bedrock-ucd-gen): generalize CodeEmitter.emit over Value

emit is now generic; valueTypeName parameter spells the TwoStageTrie
element type in the emitted output. main.swift passes "UInt8" for
the existing properties. Codegen re-run produces the same output as
before; existing tables unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add three expansion helpers

**Files:**
- Modify: `Sources/BedrockUcdGen/UCDParser.swift`
- Create: `Tests/BedrockUcdGenTests/ExpandSimpleCaseTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/BedrockUcdGenTests/ExpandSimpleCaseTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandSimpleUppercaseTests {

    @Test
    func emptyEntriesYieldsAllZeros() {
        let entries: [UCDEntry] = []
        let out = entries.expandSimpleUppercase()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func entryWithMappingFillsOneCodepoint() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0061, last: 0x0061, category: "Ll",
                     simpleUppercase: 0x0041),
        ]
        let out = entries.expandSimpleUppercase()
        #expect(out[0x0061] == 0x0041)
        #expect(out[0x0060] == 0)
        #expect(out[0x0062] == 0)
    }

    @Test
    func entryWithoutMappingStaysAtZero() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0041, last: 0x0041, category: "Lu",
                     simpleUppercase: 0),
        ]
        let out = entries.expandSimpleUppercase()
        #expect(out[0x0041] == 0)
    }

    @Test
    func rangeEntryWithoutMappingLeavesRangeZero() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x4E00, last: 0x9FFF, category: "Lo",
                     simpleUppercase: 0),
        ]
        let out = entries.expandSimpleUppercase()
        #expect(out[0x4E00] == 0)
        #expect(out[0x6F22] == 0)
        #expect(out[0x9FFF] == 0)
    }
}

@Suite
struct ExpandSimpleLowercaseTests {

    @Test
    func entryWithMappingFillsOneCodepoint() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0041, last: 0x0041, category: "Lu",
                     simpleLowercase: 0x0061),
        ]
        let out = entries.expandSimpleLowercase()
        #expect(out[0x0041] == 0x0061)
        #expect(out[0x0040] == 0)
    }
}

@Suite
struct ExpandSimpleTitlecaseTests {

    @Test
    func entryWithMappingFillsOneCodepoint() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x01C5, last: 0x01C5, category: "Lt",
                     simpleTitlecase: 0x01C5),
        ]
        let out = entries.expandSimpleTitlecase()
        #expect(out[0x01C5] == 0x01C5)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter ExpandSimple 2>&1 | tail -10
```
Expected: compile error — the three new helpers don't exist.

- [ ] **Step 3: Implement expansion helpers**

In `Sources/BedrockUcdGen/UCDParser.swift`, find the existing `public extension Array where Element == UCDEntry { ... }` block. Append three new methods inside that block:
```swift
    /// Expand to a 0x110000-element uncompacted array of simple-uppercase
    /// target codepoints. 0 means identity (no mapping).
    func expandSimpleUppercase() -> [UInt32] {
        var out = [UInt32](repeating: 0, count: 0x110000)
        for entry in self where entry.simpleUppercase != 0 {
            for cp in entry.first...entry.last {
                out[Int(cp)] = entry.simpleUppercase
            }
        }
        return out
    }

    func expandSimpleLowercase() -> [UInt32] {
        var out = [UInt32](repeating: 0, count: 0x110000)
        for entry in self where entry.simpleLowercase != 0 {
            for cp in entry.first...entry.last {
                out[Int(cp)] = entry.simpleLowercase
            }
        }
        return out
    }

    func expandSimpleTitlecase() -> [UInt32] {
        var out = [UInt32](repeating: 0, count: 0x110000)
        for entry in self where entry.simpleTitlecase != 0 {
            for cp in entry.first...entry.last {
                out[Int(cp)] = entry.simpleTitlecase
            }
        }
        return out
    }
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter ExpandSimple 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 6 new tests pass (4 + 1 + 1); full suite green at 607.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add three simple-case-mapping expansion helpers

expandSimpleUppercase, expandSimpleLowercase, expandSimpleTitlecase.
Each produces a 0x110000-element [UInt32] where 0 means identity.
Non-throwing — no abbreviation lookup; values are already codepoints.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Six-table codegen run

**Files:**
- Create: `Sources/UnicodeProperties/Generated/SimpleUppercaseTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/SimpleLowercaseTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/SimpleTitlecaseTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated files**

Create each of the three new files with the same placeholder template:

`Sources/UnicodeProperties/Generated/SimpleUppercaseTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let simpleUppercaseTable = TwoStageTrie<UInt32>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt32(0), count: 256)   // 0 = identity
)
```

`Sources/UnicodeProperties/Generated/SimpleLowercaseTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let simpleLowercaseTable = TwoStageTrie<UInt32>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt32(0), count: 256)
)
```

`Sources/UnicodeProperties/Generated/SimpleTitlecaseTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let simpleTitlecaseTable = TwoStageTrie<UInt32>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt32(0), count: 256)
)
```

Verify the package builds:
```bash
swift build 2>&1 | tail -3
```

- [ ] **Step 2: Extend main.swift to emit six tables**

The existing `main.swift` has one loop that handles three `UInt8` properties. Add a second loop after it for the three `UInt32` properties. The tuple types differ, so two loops is cleaner than one heterogeneous loop.

Replace `Sources/bedrock-ucd-gen/main.swift` with:

```swift
import Foundation
import BedrockUcdGen

let ucdPath = "Sources/UnicodeProperties/UCD/UnicodeData.txt"
let unicodeVersion = "16.0.0"

let uint8Outputs: [(String, String, String, ([UCDEntry]) throws -> [UInt8])] = [
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

let uint32Outputs: [(String, String, String, ([UCDEntry]) -> [UInt32])] = [
    ("Sources/UnicodeProperties/Generated/SimpleUppercaseTable.swift",
     "simpleUppercaseTable", "simple uppercase",
     { $0.expandSimpleUppercase() }),
    ("Sources/UnicodeProperties/Generated/SimpleLowercaseTable.swift",
     "simpleLowercaseTable", "simple lowercase",
     { $0.expandSimpleLowercase() }),
    ("Sources/UnicodeProperties/Generated/SimpleTitlecaseTable.swift",
     "simpleTitlecaseTable", "simple titlecase",
     { $0.expandSimpleTitlecase() }),
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

func emitUInt8(_ outputPath: String, _ globalName: String, _ label: String,
                _ uncompacted: [UInt8]) {
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
    let src = CodeEmitter.emit(trie, unicodeVersion: unicodeVersion,
                                globalName: globalName, valueTypeName: "UInt8")
    do {
        try src.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Wrote \(outputPath) (\(src.utf8.count) bytes).")
    } catch {
        print("Write error for \(label): \(error)")
        exit(1)
    }
}

func emitUInt32(_ outputPath: String, _ globalName: String, _ label: String,
                 _ uncompacted: [UInt32]) {
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
    let src = CodeEmitter.emit(trie, unicodeVersion: unicodeVersion,
                                globalName: globalName, valueTypeName: "UInt32")
    do {
        try src.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Wrote \(outputPath) (\(src.utf8.count) bytes).")
    } catch {
        print("Write error for \(label): \(error)")
        exit(1)
    }
}

for (outputPath, globalName, label, expand) in uint8Outputs {
    print("---")
    print("Processing: \(label)")
    let uncompacted: [UInt8]
    do {
        uncompacted = try expand(entries)
    } catch {
        print("Expansion error for \(label): \(error)")
        exit(1)
    }
    emitUInt8(outputPath, globalName, label, uncompacted)
}

for (outputPath, globalName, label, expand) in uint32Outputs {
    print("---")
    print("Processing: \(label)")
    let uncompacted = expand(entries)
    emitUInt32(outputPath, globalName, label, uncompacted)
}
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -30
```
Expected: 6 "Processing" sections + self-check + Wrote lines. Each self-check shows 1114112 codepoints round-tripping. Six files written.

STOP and report if any self-check fails.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite green at 607.

- [ ] **Step 5: Spot-check generated files**

```bash
wc -l Sources/UnicodeProperties/Generated/Simple*.swift
wc -c Sources/UnicodeProperties/Generated/Simple*.swift
head -5 Sources/UnicodeProperties/Generated/SimpleUppercaseTable.swift
```
Expected: each starts with the GENERATED banner; report sizes. Each ~200-300 KB likely (per spec).

- [ ] **Step 6: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit three simple-case-mapping tables

main.swift gains a second loop for UInt32 properties. Three new
generated tables (simpleUppercaseTable, simpleLowercaseTable,
simpleTitlecaseTable). Each is TwoStageTrie<UInt32> with 0 = identity.
Per-property self-check confirms all 1114112 codepoints round-trip.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Public API + spot-check tests

**Files:**
- Create: `Sources/UnicodeProperties/SimpleCaseMapping.swift`
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/SimpleCaseMappingTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/UnicodePropertiesTests/SimpleCaseMappingTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct SimpleCaseMappingTests {

    @Test
    func asciiBidirectionalPairs() {
        #expect(UnicodeProperties.simpleLowercase(of: "A") == "a")
        #expect(UnicodeProperties.simpleLowercase(of: "Z") == "z")
        #expect(UnicodeProperties.simpleUppercase(of: "a") == "A")
        #expect(UnicodeProperties.simpleUppercase(of: "z") == "Z")
    }

    @Test
    func asciiTitlecaseOfLowercaseIsUppercase() {
        #expect(UnicodeProperties.simpleTitlecase(of: "a") == "A")
    }

    @Test
    func asciiIdentities() {
        #expect(UnicodeProperties.simpleUppercase(of: "A") == "A")
        #expect(UnicodeProperties.simpleLowercase(of: "a") == "a")
    }

    @Test
    func asciiNonLettersIdentity() {
        #expect(UnicodeProperties.simpleUppercase(of: "5") == "5")
        #expect(UnicodeProperties.simpleLowercase(of: " ") == " ")
        #expect(UnicodeProperties.simpleTitlecase(of: "!") == "!")
    }

    @Test
    func titlecaseLetterU01C5() {
        let titlecase = Unicode.Scalar(0x01C5)!
        #expect(UnicodeProperties.simpleUppercase(of: titlecase) == Unicode.Scalar(0x01C4)!)
        #expect(UnicodeProperties.simpleLowercase(of: titlecase) == Unicode.Scalar(0x01C6)!)
        #expect(UnicodeProperties.simpleTitlecase(of: titlecase) == titlecase)
    }

    @Test
    func latin1Supplement() {
        // À (U+00C0) -> à (U+00E0)
        #expect(UnicodeProperties.simpleLowercase(of: Unicode.Scalar(0x00C0)!) == Unicode.Scalar(0x00E0)!)
        #expect(UnicodeProperties.simpleUppercase(of: Unicode.Scalar(0x00E0)!) == Unicode.Scalar(0x00C0)!)
    }

    @Test
    func greekCapitalSigma() {
        // Σ (U+03A3) -> σ (U+03C3)
        #expect(UnicodeProperties.simpleLowercase(of: Unicode.Scalar(0x03A3)!) == Unicode.Scalar(0x03C3)!)
    }

    @Test
    func cjkIdentity() {
        // U+6F22 (漢) has no case mapping
        let cjk = Unicode.Scalar(0x6F22)!
        #expect(UnicodeProperties.simpleUppercase(of: cjk) == cjk)
        #expect(UnicodeProperties.simpleLowercase(of: cjk) == cjk)
        #expect(UnicodeProperties.simpleTitlecase(of: cjk) == cjk)
    }

    @Test
    func sharpSStaysIdentityInV1() {
        // ß (U+00DF) — no single-codepoint uppercase (would need SpecialCasing.txt)
        let sharpS = Unicode.Scalar(0x00DF)!
        #expect(UnicodeProperties.simpleUppercase(of: sharpS) == sharpS)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter SimpleCaseMappingTests 2>&1 | tail -5
```
Expected: compile error.

- [ ] **Step 3: Implement entry points**

Create `Sources/UnicodeProperties/SimpleCaseMapping.swift` as a comment-only marker file documenting the layout choice:
```swift
// SimpleCaseMapping entry points live in UnicodeProperties.swift to keep
// the namespace surface co-located with other property accessors. This
// file exists to match the file-per-property layout established by
// BidiClass.swift and CanonicalCombiningClass.swift.
```

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add the three entry points after `canonicalCombiningClass(of:)`:

```swift
    /// Simple uppercase mapping (UnicodeData.txt field 12).
    /// Returns the input scalar unchanged when no mapping exists.
    ///
    /// "Simple" = single-codepoint mapping only. Multi-codepoint cases
    /// (e.g., "ß" → "SS") and locale-dependent cases (Turkish dotted/
    /// dotless I) require SpecialCasing.txt; that's a separate sub-project.
    @inlinable
    public static func simpleUppercase(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        let raw = simpleUppercaseTable.lookup(scalar.value)
        return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
    }

    /// Simple lowercase mapping (UnicodeData.txt field 13).
    @inlinable
    public static func simpleLowercase(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        let raw = simpleLowercaseTable.lookup(scalar.value)
        return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
    }

    /// Simple titlecase mapping (UnicodeData.txt field 14).
    @inlinable
    public static func simpleTitlecase(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        let raw = simpleTitlecaseTable.lookup(scalar.value)
        return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
    }
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter SimpleCaseMappingTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 9 spot-check tests pass; full suite green at 616.

If a spot-check fails, the UCD says something different — investigate via the relevant line in `UnicodeData.txt`. Do NOT alter generated tables to fit a wrong test.

- [ ] **Step 5: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add simple case mapping entry points

simpleUppercase/simpleLowercase/simpleTitlecase (of:) -> Unicode.Scalar.
Returns input unchanged for codepoints with no single-codepoint mapping.
Multi-codepoint (ß→SS) and locale-dependent (Turkish I) cases require
SpecialCasing.txt; deferred to a separate sub-project.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Extended exhaustive test + coverage + Layer 2 doc

**Files:**
- Modify: `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`
- Modify: `layers/layer-02-text-unicode.md`

- [ ] **Step 1: Extend exhaustive test**

Edit `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` to also exercise the three case-mapping entry points:

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
        _ = UnicodeProperties.simpleUppercase(of: scalar)
        _ = UnicodeProperties.simpleLowercase(of: scalar)
        _ = UnicodeProperties.simpleTitlecase(of: scalar)
    }
}
```

The three new calls only need side-effect coverage (no trap, returns a valid scalar — guaranteed by the entry-point fallback).

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass; exhaustive test still completes in well under 2 seconds.

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
  Sources/UnicodeProperties/Internal/TwoStageTrie.swift \
  Sources/BedrockUcdGen/UCDParser.swift \
  Sources/BedrockUcdGen/TwoStageTrieBuilder.swift \
  Sources/BedrockUcdGen/CodeEmitter.swift
```
Expected: each file ≥ 90% line coverage. (Generated tables are excluded; SimpleCaseMapping.swift is a comment-only marker and may show 0 instrumented regions, which is fine.)

If any file falls short, follow the established pattern: identify uncovered lines and add targeted tests, or for precondition-message autoclosures drop the message string.

- [ ] **Step 4: Update Layer 2 doc**

Edit `layers/layer-02-text-unicode.md`, replacing the existing Status block:

```markdown
> **Status:** shipping modules:
> - `Sources/UnicodeProperties/` — UCD-derived lookup against a two-stage trie. Properties available: general category (UAX #44), bidi class (UAX #9), canonical combining class, simple case mappings (uppercase/lowercase/titlecase). Codegen tool `bedrock-ucd-gen` emits one table per property ([2.1 design](../docs/superpowers/specs/2026-05-19-unicode-properties-design.md) · [2.1 plan](../docs/superpowers/plans/2026-05-19-unicode-properties-module.md) · [2.2 design](../docs/superpowers/specs/2026-05-20-bidi-class-and-ccc-design.md) · [2.2 plan](../docs/superpowers/plans/2026-05-20-bidi-class-and-ccc-module.md) · [2.3 design](../docs/superpowers/specs/2026-05-20-simple-case-mapping-design.md) · [2.3 plan](../docs/superpowers/plans/2026-05-20-simple-case-mapping-module.md)). Unicode 16.0.0.
>
> Subsequent sub-projects (Layer 2.4–2.8): normalization (NFC/NFD/NFKC/NFKD), segmentation (UAX #29), full case mapping (`SpecialCasing.txt`) + case folding (`CaseFolding.txt`), identifier classification (UAX #31), bidi algorithm (UAX #9), ASCII helpers.
```

- [ ] **Step 5: Commit**

```bash
git add Tests/UnicodePropertiesTests layers/layer-02-text-unicode.md
git commit -m "$(cat <<'EOF'
test+docs(unicode-properties): exhaustive sweep + mark 2.3 shipped

ExhaustiveTests now exercises all six properties across ~1.1M
codepoints. Layer 2 doc updated to include simple case mappings.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(If coverage tests were added in Step 3, fold them in or commit separately.)

---

## Plan Self-Review Notes

- **Spec coverage:** Every spec item — extended `UCDEntry`, parser extension, three expansion helpers, generic `BuiltTrie`/`build`/`emit`, three generated tables, three entry points — has a task. Every test category in the spec is covered.
- **No placeholders:** Every step shows runnable code or an exact command.
- **Type consistency:** Three `simple*` UCD fields are `UInt32`; entry points return `Unicode.Scalar`; storage convention `0 = identity` consistent across plan.
- **Backward-compat handling:** Task 2 generalizes the builder; Task 3 generalizes the emitter and updates existing call sites. Tasks 2 and 3 each verify the existing tests still pass + add one new test for the generic variant.
- **Placeholder tables in Task 5 Step 1:** ensures the package keeps building before `swift run bedrock-ucd-gen` produces real tables. Without these, any reference to the new globals would fail.
- **Six-table codegen** in Task 5 Step 3 includes a per-property self-check; the run aborts on any single mismatch.
- **Task 6 references the new globals**; the placeholders from Task 5 ensure the package compiles even when the real tables haven't yet been regenerated.
- **No `String` extensions or string-level case conversion.** Stays scalar-level per spec.

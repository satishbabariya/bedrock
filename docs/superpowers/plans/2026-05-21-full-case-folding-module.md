# Full Case Folding Implementation Plan (Layer 2.6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `UnicodeProperties.fullCaseFolded(of:)` per the spec at `docs/superpowers/specs/2026-05-21-full-case-folding-design.md`. Introduce variable-length storage to the codegen pipeline via an index trie + flat scalar table.

**Architecture:** New `expandFullCaseFolding()` extension on `[CaseFoldingEntry]` returns `(index: [UInt32], flat: [UInt32])`. New `FlatArrayEmitter` formats raw `[UInt32]` arrays. Two new generated tables: an index trie (via existing `CodeEmitter` with `valueTypeName: "UInt32"`) and a flat array file (via the new emitter). One new `@inlinable` entry point returning `[Unicode.Scalar]`.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing.

---

## File Structure (additions / modifications)

**Modifications:**
- `Sources/BedrockUcdGen/CaseFoldingParser.swift` — append `expandFullCaseFolding()` to the existing `Array<CaseFoldingEntry>` extension.
- `Sources/bedrock-ucd-gen/main.swift` — append a full-case-folding emission step after the existing simple-case-folding step.
- `Sources/UnicodeProperties/UnicodeProperties.swift` — add `fullCaseFolded(of:)` entry point.
- `Tests/UnicodePropertiesTests/ExhaustiveTests.swift` — sweep the new entry point.

**Creations:**
- `Sources/BedrockUcdGen/FlatArrayEmitter.swift`
- `Sources/UnicodeProperties/FullCaseFolding.swift` (comment-only marker)
- `Sources/UnicodeProperties/Generated/FullCaseFoldingIndexTable.swift` (placeholder, then real)
- `Sources/UnicodeProperties/Generated/FullCaseFoldingFlatTable.swift` (placeholder, then real)
- `Tests/BedrockUcdGenTests/ExpandFullCaseFoldingTests.swift`
- `Tests/BedrockUcdGenTests/FlatArrayEmitterTests.swift`
- `Tests/UnicodePropertiesTests/FullCaseFoldingTests.swift`

---

## Task 1: `expandFullCaseFolding` helper

**Files:**
- Modify: `Sources/BedrockUcdGen/CaseFoldingParser.swift` (append to the existing extension)
- Create: `Tests/BedrockUcdGenTests/ExpandFullCaseFoldingTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/ExpandFullCaseFoldingTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandFullCaseFoldingTests {

    @Test
    func emptyEntriesYieldsSentinelOnlyFlat() {
        let entries: [CaseFoldingEntry] = []
        let (index, flat) = entries.expandFullCaseFolding()
        #expect(index.count == 0x110000)
        #expect(index.allSatisfy { $0 == 0 })
        #expect(flat == [0])
    }

    @Test
    func singleCommonEntryProducesLengthOne() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let packed = index[0x0041]
        let offset = Int(packed >> 8)
        let length = Int(packed & 0xFF)
        #expect(length == 1)
        #expect(offset == 1)              // sentinel at 0, first real entry at 1
        #expect(flat[offset] == 0x0061)
        #expect(flat == [0, 0x0061])
    }

    @Test
    func singleFullEntryWithTwoCodepoints() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x00DF, status: .full,
                              mapping: [0x0073, 0x0073]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let packed = index[0x00DF]
        let offset = Int(packed >> 8)
        let length = Int(packed & 0xFF)
        #expect(length == 2)
        #expect(offset == 1)
        #expect(flat[offset] == 0x0073)
        #expect(flat[offset + 1] == 0x0073)
        #expect(flat == [0, 0x0073, 0x0073])
    }

    @Test
    func singleFullEntryWithThreeCodepoints() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0xFB03, status: .full,
                              mapping: [0x0066, 0x0066, 0x0069]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let packed = index[0xFB03]
        let length = Int(packed & 0xFF)
        let offset = Int(packed >> 8)
        #expect(length == 3)
        #expect(offset == 1)
        #expect(flat == [0, 0x0066, 0x0066, 0x0069])
    }

    @Test
    func fullOverridesCommonOnSameCodepoint() {
        // Synthetic case: not in real UCD, but defensive design must handle it.
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
            CaseFoldingEntry(codepoint: 0x0041, status: .full,
                              mapping: [0x0061, 0x0301]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let packed = index[0x0041]
        let offset = Int(packed >> 8)
        let length = Int(packed & 0xFF)
        #expect(length == 2)
        // Both mappings present in flat; index points at the F slot.
        #expect(flat[offset] == 0x0061)
        #expect(flat[offset + 1] == 0x0301)
    }

    @Test
    func simpleAndTurkicEntriesAreSkipped() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x1E9E, status: .simple, mapping: [0x00DF]),
            CaseFoldingEntry(codepoint: 0x0130, status: .turkic, mapping: [0x0069]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        #expect(index[0x1E9E] == 0)
        #expect(index[0x0130] == 0)
        #expect(flat == [0])
    }

    @Test
    func multipleFullEntriesGetDistinctOffsets() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x00DF, status: .full,
                              mapping: [0x0073, 0x0073]),
            CaseFoldingEntry(codepoint: 0x0130, status: .full,
                              mapping: [0x0069, 0x0307]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let p1 = index[0x00DF]
        let p2 = index[0x0130]
        let o1 = Int(p1 >> 8)
        let o2 = Int(p2 >> 8)
        #expect(o1 != o2)
        #expect(p1 & 0xFF == 2)
        #expect(p2 & 0xFF == 2)
        // Flat table has both pairs after the sentinel.
        #expect(flat == [0, 0x0073, 0x0073, 0x0069, 0x0307])
    }

    @Test
    func mixedRealisticInput() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
            CaseFoldingEntry(codepoint: 0x00DF, status: .full,
                              mapping: [0x0073, 0x0073]),
            CaseFoldingEntry(codepoint: 0x0130, status: .full,
                              mapping: [0x0069, 0x0307]),
            CaseFoldingEntry(codepoint: 0x0130, status: .turkic, mapping: [0x0069]),
            CaseFoldingEntry(codepoint: 0x1E9E, status: .simple, mapping: [0x00DF]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        #expect(index[0x0041] != 0)
        #expect(index[0x00DF] != 0)
        #expect(index[0x0130] != 0)
        #expect(index[0x1E9E] == 0)   // S skipped
        // flat = [0, 0x0061, 0x0073, 0x0073, 0x0069, 0x0307]
        #expect(flat == [0, 0x0061, 0x0073, 0x0073, 0x0069, 0x0307])
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter ExpandFullCaseFoldingTests 2>&1 | tail -10
```
Expected: compile error — `expandFullCaseFolding` doesn't exist.

- [ ] **Step 3: Implement the helper**

In `Sources/BedrockUcdGen/CaseFoldingParser.swift`, the existing `public extension Array where Element == CaseFoldingEntry { ... }` block currently contains `expandSimpleCaseFolding`. Append the new helper inside the same block (after `expandSimpleCaseFolding`):

```swift
    /// Returns (indexTable, flatTable) for full case folding.
    ///
    /// indexTable: 0x110000-element [UInt32] where 0 = identity, else
    ///   value = (offset << 8) | length pointing into flatTable.
    /// flatTable: concatenated target codepoints. flatTable[0] is a
    ///   reserved sentinel; real entries start at offset 1.
    ///
    /// Two-pass: C entries first (single-codepoint), then F entries
    /// override them (full-folding spec). S and T entries skipped.
    func expandFullCaseFolding() -> (index: [UInt32], flat: [UInt32]) {
        var index = [UInt32](repeating: 0, count: 0x110000)
        var flat: [UInt32] = [0]   // sentinel

        for entry in self
            where entry.status == .common && entry.mapping.count == 1 {
            let offset = UInt32(flat.count)
            flat.append(entry.mapping[0])
            index[Int(entry.codepoint)] = (offset << 8) | 1
        }

        for entry in self
            where entry.status == .full && !entry.mapping.isEmpty {
            precondition(entry.mapping.count <= 0xFF,
                         "F mapping length exceeds 8-bit encoding")
            let offset = UInt32(flat.count)
            precondition(offset < (1 << 24),
                         "flat table offset exceeds 24-bit encoding")
            for cp in entry.mapping { flat.append(cp) }
            let length = UInt32(entry.mapping.count)
            index[Int(entry.codepoint)] = (offset << 8) | length
        }

        return (index, flat)
    }
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter ExpandFullCaseFoldingTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 8 helper tests pass; full suite green at 678.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add expandFullCaseFolding helper

Returns (indexTable, flatTable) with variable-length encoding:
24-bit offset + 8-bit length packed into UInt32; flat[0] is a
reserved sentinel. Two-pass C-then-F write so F overrides C; S
and T entries skipped. Codegen-time preconditions guard against
length and offset overflow (max observed length 3, max offset
~1700 in UCD 16.0; both well below limits).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `FlatArrayEmitter`

**Files:**
- Create: `Sources/BedrockUcdGen/FlatArrayEmitter.swift`
- Create: `Tests/BedrockUcdGenTests/FlatArrayEmitterTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BedrockUcdGenTests/FlatArrayEmitterTests.swift`:
```swift
import Testing
@testable import BedrockUcdGen

@Suite
struct FlatArrayEmitterTests {

    @Test
    func headerContainsExpectedTokens() {
        let src = FlatArrayEmitter.emit([0, 1, 2, 3],
                                          unicodeVersion: "16.0.0",
                                          globalName: "exampleTable")
        #expect(src.contains("GENERATED"))
        #expect(src.contains("16.0.0"))
        #expect(src.contains("@usableFromInline"))
        #expect(src.contains("internal let exampleTable: [UInt32]"))
    }

    @Test
    func emitsArrayContents() {
        let src = FlatArrayEmitter.emit([42, 100, 255],
                                          unicodeVersion: "16.0.0",
                                          globalName: "exampleTable")
        #expect(src.contains("42"))
        #expect(src.contains("100"))
        #expect(src.contains("255"))
    }

    @Test
    func emptyArrayProducesValidLiteral() {
        let src = FlatArrayEmitter.emit([],
                                          unicodeVersion: "16.0.0",
                                          globalName: "exampleTable")
        #expect(src.contains("internal let exampleTable: [UInt32]"))
        #expect(src.contains("["))
        #expect(src.contains("]"))
    }

    @Test
    func balancedBrackets() {
        let src = FlatArrayEmitter.emit(Array(repeating: UInt32(1), count: 32),
                                          unicodeVersion: "16.0.0",
                                          globalName: "exampleTable")
        #expect(src.filter({ $0 == "[" }).count == src.filter({ $0 == "]" }).count)
    }

    @Test
    func usesProvidedGlobalName() {
        let src = FlatArrayEmitter.emit([1, 2, 3],
                                          unicodeVersion: "16.0.0",
                                          globalName: "myCustomFlat")
        #expect(src.contains("internal let myCustomFlat: [UInt32]"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter FlatArrayEmitterTests 2>&1 | tail -5
```
Expected: compile error.

- [ ] **Step 3: Implement the emitter**

Create `Sources/BedrockUcdGen/FlatArrayEmitter.swift`:
```swift
public enum FlatArrayEmitter {

    public static func emit(_ array: [UInt32],
                            unicodeVersion: String,
                            globalName: String) -> String {
        var out = ""
        out += "// GENERATED by `swift run bedrock-ucd-gen`. Do not edit by hand.\n"
        out += "// Source: Sources/UnicodeProperties/UCD/CaseFolding.txt "
        out += "(Unicode \(unicodeVersion))\n"
        out += "\n"
        out += "@usableFromInline\n"
        out += "internal let \(globalName): [UInt32] = [\n"
        out += formatArray(array, indent: "    ")
        out += "\n]\n"
        return out
    }

    private static func formatArray(_ values: [UInt32], indent: String) -> String {
        if values.isEmpty { return indent }
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
swift test --filter FlatArrayEmitterTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 5 emitter tests pass; full suite green at 683.

- [ ] **Step 5: Commit**

```bash
git add Sources/BedrockUcdGen Tests/BedrockUcdGenTests
git commit -m "$(cat <<'EOF'
feat(bedrock-ucd-gen): add FlatArrayEmitter

Emits a Swift file declaring a raw [UInt32] global. Separate from
CodeEmitter (which emits TwoStageTrie-wrapped output) since the flat
table for variable-length properties has a different shape. 16
values per line, decimal.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Codegen run

**Files:**
- Create: `Sources/UnicodeProperties/Generated/FullCaseFoldingIndexTable.swift` (placeholder first)
- Create: `Sources/UnicodeProperties/Generated/FullCaseFoldingFlatTable.swift` (placeholder first)
- Modify: `Sources/bedrock-ucd-gen/main.swift`

- [ ] **Step 1: Add placeholder generated files**

Create `Sources/UnicodeProperties/Generated/FullCaseFoldingIndexTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let fullCaseFoldingIndexTable = TwoStageTrie<UInt32>(
    stage1: Array(repeating: UInt16(0), count: 4352),
    stage2: Array(repeating: UInt32(0), count: 256)
)
```

Create `Sources/UnicodeProperties/Generated/FullCaseFoldingFlatTable.swift`:
```swift
// PLACEHOLDER — real table generated by `swift run bedrock-ucd-gen` later in this task.

@usableFromInline
internal let fullCaseFoldingFlatTable: [UInt32] = [0]
```

Verify build:
```bash
swift build 2>&1 | tail -3
```

- [ ] **Step 2: Extend main.swift**

Read `Sources/bedrock-ucd-gen/main.swift` first to locate the simple-case-folding step. The variable `cfEntries` is already in scope there. AFTER the existing simple-folding emit call, append:

```swift
print("---")
print("Processing: full case folding (CaseFolding.txt)")
let (fcfIndex, fcfFlat) = cfEntries.expandFullCaseFolding()
print("Full folding: flat table size = \(fcfFlat.count)")

emitUInt32("Sources/UnicodeProperties/Generated/FullCaseFoldingIndexTable.swift",
            "fullCaseFoldingIndexTable", "full case folding index", fcfIndex)

let flatSrc = FlatArrayEmitter.emit(fcfFlat,
                                     unicodeVersion: unicodeVersion,
                                     globalName: "fullCaseFoldingFlatTable")
let flatPath = "Sources/UnicodeProperties/Generated/FullCaseFoldingFlatTable.swift"
do {
    try flatSrc.write(toFile: flatPath, atomically: true, encoding: .utf8)
    print("Wrote \(flatPath) (\(flatSrc.utf8.count) bytes).")
} catch {
    print("Write error: \(error)")
    exit(1)
}
```

- [ ] **Step 3: Run codegen**

```bash
swift run bedrock-ucd-gen 2>&1 | tail -25
```
Expected: existing 9 emissions plus 2 new ones (full case folding index + flat). The index self-checks via `emitUInt32` (1114112 codepoints round-trip). The flat table has size ~1700 (1 sentinel + 1453 C + 88×2 + 16×3 = 1678).

If self-check fails — STOP and report.

- [ ] **Step 4: Verify package builds and tests pass**

```bash
swift build 2>&1 | tail -3
swift test 2>&1 | tail -3
```
Expected: builds clean; full suite green at 683 (no API references the new tables yet).

- [ ] **Step 5: Spot-check generated files**

```bash
wc -c Sources/UnicodeProperties/Generated/FullCaseFolding*.swift
head -5 Sources/UnicodeProperties/Generated/FullCaseFoldingIndexTable.swift
head -5 Sources/UnicodeProperties/Generated/FullCaseFoldingFlatTable.swift
```
Expected: each starts with GENERATED banner; sizes roughly 30-40 KB (index) + 15-20 KB (flat).

- [ ] **Step 6: Verify the other 9 tables unchanged**

```bash
git diff --stat Sources/UnicodeProperties/Generated/
```
Expected: only the two new full-folding tables show changes (placeholder → real). No diff on the other 9.

- [ ] **Step 7: Commit**

```bash
git add Sources/bedrock-ucd-gen Sources/UnicodeProperties/Generated
git commit -m "$(cat <<'EOF'
feat(unicode-properties): emit FullCaseFoldingIndex + Flat tables

bedrock-ucd-gen extended with full-case-folding emission step: index
trie via existing CodeEmitter, flat scalar array via new
FlatArrayEmitter. Self-check confirms all 1114112 codepoints
round-trip through the index trie; flat table sized exactly per the
parsed C and F entries.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `fullCaseFolded(of:)` public API

**Files:**
- Create: `Sources/UnicodeProperties/FullCaseFolding.swift` (comment-only marker)
- Modify: `Sources/UnicodeProperties/UnicodeProperties.swift`
- Create: `Tests/UnicodePropertiesTests/FullCaseFoldingTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/UnicodePropertiesTests/FullCaseFoldingTests.swift`:
```swift
import Testing
import UnicodeProperties

@Suite
struct FullCaseFoldingTests {

    private func folded(_ scalar: Unicode.Scalar) -> [Unicode.Scalar] {
        UnicodeProperties.fullCaseFolded(of: scalar)
    }

    @Test
    func asciiUppercaseFoldsToLowercase() {
        #expect(folded("A") == ["a"])
        #expect(folded("Z") == ["z"])
    }

    @Test
    func asciiLowercaseIsIdentity() {
        #expect(folded("a") == ["a"])
        #expect(folded("z") == ["z"])
    }

    @Test
    func asciiNonLettersIdentity() {
        #expect(folded("5") == ["5"])
        #expect(folded(" ") == [" "])
        #expect(folded("!") == ["!"])
    }

    @Test
    func latin1Uppercase() {
        // À U+00C0 -> à U+00E0
        #expect(folded(Unicode.Scalar(0x00C0)!) == [Unicode.Scalar(0x00E0)!])
    }

    @Test
    func sharpSExpandsToTwoEsses() {
        // The headline F result: ß -> ss
        let result = folded(Unicode.Scalar(0x00DF)!)
        #expect(result == [Unicode.Scalar(0x0073)!, Unicode.Scalar(0x0073)!])
    }

    @Test
    func turkishDottedI() {
        // U+0130 -> i + combining dot above (0x0069 0x0307)
        let result = folded(Unicode.Scalar(0x0130)!)
        #expect(result == [Unicode.Scalar(0x0069)!, Unicode.Scalar(0x0307)!])
    }

    @Test
    func ffiLigatureExpandsToThree() {
        // U+FB03 ﬃ -> f f i
        let result = folded(Unicode.Scalar(0xFB03)!)
        #expect(result == [Unicode.Scalar(0x0066)!,
                            Unicode.Scalar(0x0066)!,
                            Unicode.Scalar(0x0069)!])
    }

    @Test
    func greekIotaWithDialytikaAndTonos() {
        // U+0390 ΐ -> ι ̈ ́ = 03B9 0308 0301 (three codepoints)
        let result = folded(Unicode.Scalar(0x0390)!)
        #expect(result == [Unicode.Scalar(0x03B9)!,
                            Unicode.Scalar(0x0308)!,
                            Unicode.Scalar(0x0301)!])
    }

    @Test
    func greekSigmaCluster() {
        let sigma = Unicode.Scalar(0x03C3)!
        #expect(folded(Unicode.Scalar(0x03A3)!) == [sigma])
        #expect(folded(Unicode.Scalar(0x03C2)!) == [sigma])
        #expect(folded(sigma) == [sigma])
    }

    @Test
    func cjkIdentity() {
        let cjk = Unicode.Scalar(0x6F22)!
        #expect(folded(cjk) == [cjk])
    }

    @Test
    func titlecaseLetterFoldsLikeSimple() {
        // U+01C5 ǅ -> ǆ U+01C6 (C entry; same as simple folding)
        #expect(folded(Unicode.Scalar(0x01C5)!) == [Unicode.Scalar(0x01C6)!])
    }

    @Test
    func resultIsAlwaysNonEmpty() {
        for cp: UInt32 in [0x0000, 0x0041, 0x00DF, 0xFB03, 0x6F22, 0x10000] {
            let scalar = Unicode.Scalar(cp)!
            let result = folded(scalar)
            #expect(result.isEmpty == false,
                    "fullCaseFolded should never return empty (cp U+\(String(cp, radix: 16)))")
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
swift test --filter FullCaseFoldingTests 2>&1 | tail -5
```
Expected: compile error.

- [ ] **Step 3: Create marker file**

Create `Sources/UnicodeProperties/FullCaseFolding.swift`:
```swift
// FullCaseFolding entry point lives in UnicodeProperties.swift to keep
// the namespace surface co-located with other property accessors.
// This file exists to match the file-per-property layout established
// by BidiClass.swift, CanonicalCombiningClass.swift, SimpleCaseMapping.swift,
// CaseFolding.swift, and Identifier.swift.
```

- [ ] **Step 4: Add the entry point**

In `Sources/UnicodeProperties/UnicodeProperties.swift`, add immediately after `caseFolded(of:)`:

```swift
    /// Full case folding (CaseFolding.txt statuses C + F — single OR
    /// multi-codepoint output).
    ///
    /// Returns a non-empty array of `Unicode.Scalar`:
    /// - For most codepoints (no folding): `[scalar]` (identity).
    /// - For `C`-folded codepoints: `[targetCp]` (e.g., `"A"` → `["a"]`).
    /// - For `F`-folded codepoints: 2–3 codepoints
    ///   (e.g., `"ß"` (U+00DF) → `["s", "s"]`,
    ///    `"İ"` (U+0130) → `["i", "\u{0307}"]`,
    ///    `"ﬃ"` (U+FB03) → `["f", "f", "i"]`).
    ///
    /// Turkic-locale folding (status `T`) is locale-dependent and not
    /// applied; consumers needing Turkish folding must override at a
    /// higher layer.
    @inlinable
    public static func fullCaseFolded(of scalar: Unicode.Scalar) -> [Unicode.Scalar] {
        let packed = fullCaseFoldingIndexTable.lookup(scalar.value)
        if packed == 0 { return [scalar] }
        let offset = Int(packed >> 8)
        let length = Int(packed & 0xFF)
        var result: [Unicode.Scalar] = []
        result.reserveCapacity(length)
        for i in 0..<length {
            result.append(Unicode.Scalar(fullCaseFoldingFlatTable[offset + i])!)
        }
        return result
    }
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter FullCaseFoldingTests 2>&1 | tail -10
swift test 2>&1 | tail -3
```
Expected: 12 spot-check tests pass; full suite green at 695.

If a multi-codepoint case (ß, İ, ﬃ, ΐ) fails, the codegen has a bug — investigate via the corresponding line in `Sources/UnicodeProperties/UCD/CaseFolding.txt`. Do NOT alter the generated table or weaken the test.

- [ ] **Step 6: Commit**

```bash
git add Sources/UnicodeProperties Tests/UnicodePropertiesTests
git commit -m "$(cat <<'EOF'
feat(unicode-properties): add fullCaseFolded(of:) entry point

Returns [Unicode.Scalar] of length 1, 2, or 3. Identity for most
codepoints; single-codepoint for C-folded; multi-codepoint for
F-folded (ß→ss, İ→i+combining dot, ﬃ→ffi, ΐ→3 codepoints).
Turkic-locale folding (T) explicitly skipped.

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

In `Tests/UnicodePropertiesTests/ExhaustiveTests.swift`, add inside the existing loop (after `isXIDContinue`):
```swift
            _ = UnicodeProperties.fullCaseFolded(of: scalar)
```

- [ ] **Step 2: Run full suite**

```bash
swift test 2>&1 | tail -3
```
Expected: 695 tests pass. The exhaustive test does 1.1M array allocations; runtime under ~3s.

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
  Sources/BedrockUcdGen/CodeEmitter.swift \
  Sources/BedrockUcdGen/FlatArrayEmitter.swift
```
Expected: each file ≥ 90% line coverage.

If `CaseFoldingParser.swift` falls short due to the new helper's precondition branches: those are codegen-time defensive checks. Either add targeted synthetic-input tests that trigger them, or document them as defensive and accept the gap.

- [ ] **Step 4: Update Layer 2 doc**

Edit `layers/layer-02-text-unicode.md`. Replace the existing Status block:

```markdown
> **Status:** shipping modules:
> - `Sources/UnicodeProperties/` — UCD-derived lookup against a two-stage trie. Properties available: general category (UAX #44), bidi class (UAX #9), canonical combining class, simple case mappings (uppercase/lowercase/titlecase), simple case folding (CaseFolding.txt C+S), full case folding (CaseFolding.txt C+F, multi-codepoint), XID_Start / XID_Continue (UAX #31). Codegen tool `bedrock-ucd-gen` emits one table per property; full case folding uses a new offset+length index trie + flat scalar array shape ([2.1](../docs/superpowers/specs/2026-05-19-unicode-properties-design.md) · [2.2](../docs/superpowers/specs/2026-05-20-bidi-class-and-ccc-design.md) · [2.3](../docs/superpowers/specs/2026-05-20-simple-case-mapping-design.md) · [2.4](../docs/superpowers/specs/2026-05-20-simple-case-folding-design.md) · [2.5](../docs/superpowers/specs/2026-05-21-xid-properties-design.md) · [2.6](../docs/superpowers/specs/2026-05-21-full-case-folding-design.md)). Unicode 16.0.0.
>
> Subsequent sub-projects (Layer 2.7–2.10): normalization (NFC/NFD/NFKC/NFKD), segmentation (UAX #29), SpecialCasing.txt, bidi algorithm (UAX #9), ASCII helpers.
```

(Plan links are omitted from this status block to keep the line manageable; design-spec links suffice as the canonical entry point.)

- [ ] **Step 5: Commit**

```bash
git add Tests/UnicodePropertiesTests layers/layer-02-text-unicode.md
git commit -m "$(cat <<'EOF'
test+docs(unicode-properties): exhaustive sweep + mark 2.6 shipped

ExhaustiveTests now exercises all ten properties (including the new
fullCaseFolded) across ~1.1M codepoints. Layer 2 doc updated to
include full case folding and the new offset+length storage shape.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(If coverage tests were added in Step 3, fold them in or commit separately.)

---

## Plan Self-Review Notes

- **Spec coverage:** every spec item — `expandFullCaseFolding`, `FlatArrayEmitter`, two generated tables, public entry point — has a task. Every test category in the spec is covered.
- **No placeholders:** every step shows runnable code or an exact command.
- **Type consistency:** offset = high 24 bits, length = low 8 bits; sentinel at `flat[0]`; identity = 0 in index. Convention is consistent across helper, tests, codegen, and runtime lookup.
- **Reuses existing infrastructure:** index trie emission goes through the existing generic `CodeEmitter.emit` (via `emitUInt32`); only the flat-array shape needs a new emitter.
- **Two-pass override semantics**: C first, then F. Doesn't occur in real UCD 16.0 but defensive.
- **Codegen-time preconditions**: guard against unrealistic future inputs (length > 255 or offset ≥ 2²⁴). Current max length = 3, max offset ~1700; preconditions are dormant.
- **No `String`-level wrapper**: stays scalar-level per spec deferral.

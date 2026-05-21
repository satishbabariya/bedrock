# Full Case Folding Design (Layer 2.6)

**Status:** Approved
**Layer:** 2 — Text & Unicode
**Depends on:** Layer 2.1–2.5 (`UnicodeProperties` library, `bedrock-ucd-gen`, `CaseFoldingParser` from 2.4)
**Date:** 2026-05-21

## Purpose

Complete the case-folding story from Layer 2.4 by shipping **full case folding** — the multi-codepoint mappings (`F` status) from `CaseFolding.txt`. Common cases:

- `ß` (U+00DF) → `["s", "s"]` (sharp s)
- `İ` (U+0130) → `["i", "\u{0307}"]` (Turkish dotted I → i + combining dot)
- `ﬃ` (U+FB03) → `["f", "f", "i"]` (Latin small ligature FFI)
- `ΐ` (U+0390) → `[ι, ̈, ́]` (3-codepoint Greek decomposition)

This sub-project also introduces **variable-length storage** to the codegen pipeline — a new shape comprising an offset+length lookup trie plus a flat scalar array. The same storage pattern will be reused later for compatibility decomposition (NFKD) and special casing.

## Scope

### In scope (v1)

- **Verified data shape**: F entries in `CaseFolding.txt` 16.0.0 have 2 or 3 codepoints each (88 two-codepoint + 16 three-codepoint; no entries exceed 3).
- **New variable-length storage**:
  - **Index trie** (`TwoStageTrie<UInt32>`): one entry per codepoint. `0` = identity (no folding; caller returns `[scalar]`). Non-zero = packed `(offset << 8) | length`, where `offset` is a 24-bit index into the flat table and `length` is 1, 2, or 3.
  - **Flat scalar table** (`[UInt32]`): concatenated target codepoints. `flat[0]` is a reserved sentinel. Real entries start at offset 1.
- **`expandFullCaseFolding()`** on `[CaseFoldingEntry]` — returns `(index: [UInt32], flat: [UInt32])` tuple. Two-pass: first writes all `C` entries (single-codepoint), then `F` entries override them (full-folding spec). Skips `S` and `T`.
- **`FlatArrayEmitter`** — a new sibling to `CodeEmitter` that emits a raw `[UInt32]` array file (a simpler shape than the trie wrapper).
- **Two new generated tables**:
  - `Sources/UnicodeProperties/Generated/FullCaseFoldingIndexTable.swift` (`TwoStageTrie<UInt32>`).
  - `Sources/UnicodeProperties/Generated/FullCaseFoldingFlatTable.swift` (`[UInt32]`).
- **`UnicodeProperties.fullCaseFolded(of:) -> [Unicode.Scalar]`** — always returns at least one scalar. For identity codepoints: `[scalar]`. For C-folded: `[targetCp]`. For F-folded: 2- or 3-codepoint array.
- Stdlib-only at runtime; Foundation in codegen only.

### Out of scope (separate work)

- **Turkic-only folding** (status `T`) — locale-dependent. Same deferral as Layer 2.4.
- **String-level `fullCaseFolded(_: String) -> String`** — needs scalar iteration with grapheme handling; v1 stays scalar-level.
- **Closure-based fast-path API** (`withFullCaseFolding(of:_:_:)` avoiding array allocation). Defer until profiling shows allocations as a bottleneck.
- **`caseInsensitiveCompare(_:_:)`** primitive — separate concern.
- **Decomposition mapping (UCD field 5)** for NFD/NFKD — Layer 2.7's problem. Same storage shape will be reused; this round establishes the pattern.

## Module Layout

```
Sources/UnicodeProperties/
├── FullCaseFolding.swift                          # new: comment-only marker
├── UnicodeProperties.swift                        # add fullCaseFolded(of:)
└── Generated/
    ├── ... existing nine tables ...
    ├── FullCaseFoldingIndexTable.swift            # new (codegen)
    └── FullCaseFoldingFlatTable.swift             # new (codegen)

Sources/BedrockUcdGen/
├── CaseFoldingParser.swift                        # extend with expandFullCaseFolding
└── FlatArrayEmitter.swift                         # new
```

```
Tests/UnicodePropertiesTests/
└── FullCaseFoldingTests.swift                     # new

Tests/BedrockUcdGenTests/
├── ExpandFullCaseFoldingTests.swift               # new
└── FlatArrayEmitterTests.swift                    # new
```

## Public API

```swift
extension UnicodeProperties {

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
    public static func fullCaseFolded(of scalar: Unicode.Scalar) -> [Unicode.Scalar]
}
```

Storage convention: `0` in the index trie = identity. Any non-zero value packs `(offset << 8) | length` into a `UInt32`. The flat table's slot 0 is a reserved sentinel; real entries begin at offset 1.

### Lookup implementation

```swift
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

The `Unicode.Scalar(_:)?` returns nil only for out-of-range values; every value we emit is a valid hex codepoint from `CaseFolding.txt`, so the force-unwrap is safe by construction.

## Codegen Changes

### `expandFullCaseFolding` helper

```swift
public extension Array where Element == CaseFoldingEntry {

    /// Returns (indexTable, flatTable) for full case folding.
    ///
    /// indexTable: 0x110000-element [UInt32] where 0 = identity, else
    ///   value = (offset << 8) | length pointing into flatTable.
    /// flatTable: concatenated target codepoints. flatTable[0] is a
    ///   reserved sentinel; real entries start at offset 1.
    func expandFullCaseFolding() -> (index: [UInt32], flat: [UInt32]) {
        var index = [UInt32](repeating: 0, count: 0x110000)
        var flat: [UInt32] = [0]   // sentinel

        // First pass: C entries (single-codepoint mapping).
        for entry in self
            where entry.status == .common && entry.mapping.count == 1 {
            let offset = UInt32(flat.count)
            flat.append(entry.mapping[0])
            index[Int(entry.codepoint)] = (offset << 8) | 1
        }

        // Second pass: F entries override C (full folding spec).
        for entry in self
            where entry.status == .full && !entry.mapping.isEmpty {
            precondition(entry.mapping.count <= 0xFF,
                         "F mapping length exceeds 8-bit encoding")
            let offset = UInt32(flat.count)
            for cp in entry.mapping { flat.append(cp) }
            let length = UInt32(entry.mapping.count)
            precondition(offset < (1 << 24),
                         "flat table offset exceeds 24-bit encoding")
            index[Int(entry.codepoint)] = (offset << 8) | length
        }

        return (index, flat)
    }
}
```

`S` and `T` entries are explicitly skipped. The two-pass order ensures F overrides C if both ever exist on the same codepoint (not present in UCD 16.0; defensive).

### `FlatArrayEmitter`

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

Kept separate from `CodeEmitter` to keep that file focused on the trie shape; `FlatArrayEmitter` is the new shape for raw arrays.

### `main.swift` extension

After the existing CaseFolding emission step (which produced `SimpleCaseFoldingTable.swift`), the existing `cfEntries` variable is in scope and reused. Append:

```swift
print("---")
print("Processing: full case folding (CaseFolding.txt)")
let (fcfIndex, fcfFlat) = cfEntries.expandFullCaseFolding()
print("Full folding: flat table size = \(fcfFlat.count)")

// Index trie via existing emitUInt32 helper
emitUInt32("Sources/UnicodeProperties/Generated/FullCaseFoldingIndexTable.swift",
            "fullCaseFoldingIndexTable", "full case folding index", fcfIndex)

// Flat table via new emitter
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

## Edge Cases

| Case | Handling |
|---|---|
| Identity codepoints | `index[cp] == 0` → caller returns `[scalar]`. |
| ASCII `"A"` (U+0041) | C entry → `["a"]`. |
| ASCII `"a"` | No entry → identity `["a"]`. |
| Greek `"Σ"` (U+03A3) | C entry → `["σ"]`. |
| Greek `"ς"` (U+03C2) | C entry → `["σ"]`. |
| `"ß"` (U+00DF) | F entry → `["s", "s"]`. **Headline result.** |
| `"İ"` (U+0130) | F entry → `["i", "\u{0307}"]`. |
| `"ﬃ"` (U+FB03 Latin Small Ligature FFI) | F entry → `["f", "f", "i"]` (3 codepoints). |
| `"ΐ"` (U+0390 Greek small iota with dialytika and tonos) | F entry → 3 codepoints. |
| Codepoint with both C and F | Doesn't occur in UCD 16.0. Defensive two-pass; F wins. |
| Length encoding overflow | Codegen `precondition`. Max observed: 3 (well under 255). |
| Offset encoding overflow | Codegen `precondition`. Flat table ~1700 entries (well under 16M). |
| Empty mapping in input | Parser already rejects in Layer 2.4. Expansion also guards (`!entry.mapping.isEmpty`). |

## Testing Strategy

Each new test file targets ≥ 90% line coverage on its corresponding source file.

### `UnicodePropertiesTests/FullCaseFoldingTests.swift`
- ASCII letters fold via C: `"A"` → `["a"]`, `"Z"` → `["z"]`.
- ASCII identities: `"a"`, `"5"`, `" "`, `"!"`.
- Latin-1 letters via C: `Unicode.Scalar(0x00C0)` → `[Unicode.Scalar(0x00E0)]`.
- **Sharp s** (U+00DF) → `[Unicode.Scalar(0x0073), Unicode.Scalar(0x0073)]`.
- Turkish dotted I (U+0130) → `[Unicode.Scalar(0x0069), Unicode.Scalar(0x0307)]`.
- Ligature ﬃ (U+FB03) → 3-codepoint result `[0x0066, 0x0066, 0x0069]`.
- Greek with dialytika and tonos (U+0390) → 3-codepoint result.
- Greek sigma cluster: Σ, ς, σ all map appropriately.
- CJK identity: U+6F22 → `[U+6F22]`.
- Titlecase letter U+01C5 → `[U+01C6]`.

### `BedrockUcdGenTests/ExpandFullCaseFoldingTests.swift`
- Empty entries → all-zero index, flat = `[0]` (sentinel only).
- Single C entry: index[cp] = `(1 << 8) | 1`, flat = `[0, target]`.
- Single F entry with 2 codepoints: index[cp] = `(1 << 8) | 2`, flat = `[0, m0, m1]`.
- Single F entry with 3 codepoints: index[cp] = `(1 << 8) | 3`, flat = `[0, m0, m1, m2]`.
- C then F on the same codepoint: index reflects F's offset; flat contains both mappings.
- S and T entries skipped (no impact on either array).

### `BedrockUcdGenTests/FlatArrayEmitterTests.swift`
- Header tokens: GENERATED, Unicode version, global name.
- Output contains expected literal values.
- Balanced brackets / parens.
- Output for an empty array still produces a syntactically valid `[UInt32]` literal.
- Output is a valid Swift array literal (smoke).

### Extended `ExhaustiveTests.swift`
- Add `_ = UnicodeProperties.fullCaseFolded(of: scalar)` inside the existing per-codepoint loop. Adds 1.1M array allocations; expected to keep total exhaustive runtime under ~3s.

## Expected output sizes (Unicode 16.0)

- **Index trie**: ~1500 codepoints with non-zero entries; rest 0. Aggressive dedup expected (~25–40 unique blocks). Estimate ~30–40 KB source.
- **Flat table**: 1 (sentinel) + 1453 (C) + 88×2 (F-2byte) + 16×3 (F-3byte) ≈ 1678 entries × 4 bytes = ~6.7 KB binary. As Swift source literal: ~15–20 KB.
- **Total new generated source**: ~50–60 KB.

## Non-Functional Requirements

- **Stdlib only** at runtime. Foundation only in codegen.
- **O(1) lookup** for the trie. Array allocation is the only non-constant-time cost in `fullCaseFolded(of:)`.
- **Sendable** end-to-end: both generated tables are `let`-bound, the trie and `[UInt32]` are value types.
- **Bounds-safe**: trie guarantees in-range index; flat-table reads use indices computed from packed values whose offset+length stay within the table size by codegen-time precondition.

## Open Questions

None. All resolved during brainstorming:
- Storage: 24-bit offset + 8-bit length packed into `UInt32`. Verified F mappings fit (max length 3, max offset ~1700).
- Sentinel: `flat[0] = 0` reserved; entries start at offset 1.
- API return type: `[Unicode.Scalar]` (allocating). Closure-based fast path deferred.
- C vs F priority: F overrides for full folding (per Unicode); two-pass codegen ensures this.
- S vs T: both skipped in v1.
- New emitter: `FlatArrayEmitter` kept separate from `CodeEmitter` (different output shape).

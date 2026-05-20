import Foundation
import BedrockUcdGen

let ucdPath = "Sources/UnicodeProperties/UCD/UnicodeData.txt"
let unicodeVersion = "16.0.0"

let outputs: [(String, String, String, ([UCDEntry]) throws -> [UInt8])] = [
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

for (outputPath, globalName, label, expand) in outputs {
    print("---")
    print("Processing: \(label)")
    let uncompacted: [UInt8]
    do {
        uncompacted = try expand(entries)
    } catch {
        print("Expansion error for \(label): \(error)")
        exit(1)
    }

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

    let src = CodeEmitter.emit(trie, unicodeVersion: unicodeVersion, globalName: globalName)
    do {
        try src.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Wrote \(outputPath) (\(src.utf8.count) bytes).")
    } catch {
        print("Write error for \(label): \(error)")
        exit(1)
    }
}

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

print("---")
print("Parsing DerivedCoreProperties.txt ...")
let dcpPath = "Sources/UnicodeProperties/UCD/DerivedCoreProperties.txt"
let dcpText: String
do {
    dcpText = try String(contentsOfFile: dcpPath, encoding: .utf8)
} catch {
    print("Failed to read \(dcpPath): \(error)")
    exit(1)
}
let dcpEntries: [DerivedCorePropertyEntry]
do {
    dcpEntries = try DerivedCorePropertyParser.parse(dcpText)
    print("Parsed \(dcpEntries.count) DerivedCoreProperty entries.")
} catch {
    print("DerivedCoreProperties parse error: \(error)")
    exit(1)
}

print("---")
print("Processing: XID_Start")
emitUInt8("Sources/UnicodeProperties/Generated/XIDStartTable.swift",
           "xidStartTable", "XID_Start", dcpEntries.expandXIDStart())

print("---")
print("Processing: XID_Continue")
emitUInt8("Sources/UnicodeProperties/Generated/XIDContinueTable.swift",
           "xidContinueTable", "XID_Continue", dcpEntries.expandXIDContinue())

let extraDcpOutputs: [(String, String, String, () -> [UInt8])] = [
    ("Sources/UnicodeProperties/Generated/IDStartTable.swift",
     "idStartTable", "ID_Start",
     { dcpEntries.expandIDStart() }),
    ("Sources/UnicodeProperties/Generated/IDContinueTable.swift",
     "idContinueTable", "ID_Continue",
     { dcpEntries.expandIDContinue() }),
    ("Sources/UnicodeProperties/Generated/MathTable.swift",
     "mathTable", "Math",
     { dcpEntries.expandMath() }),
    ("Sources/UnicodeProperties/Generated/AlphabeticTable.swift",
     "alphabeticTable", "Alphabetic",
     { dcpEntries.expandAlphabetic() }),
    ("Sources/UnicodeProperties/Generated/CasedTable.swift",
     "casedTable", "Cased",
     { dcpEntries.expandCased() }),
    ("Sources/UnicodeProperties/Generated/LowercaseTable.swift",
     "lowercaseTable", "Lowercase",
     { dcpEntries.expandLowercase() }),
    ("Sources/UnicodeProperties/Generated/UppercaseTable.swift",
     "uppercaseTable", "Uppercase",
     { dcpEntries.expandUppercase() }),
]

for (path, global, label, expand) in extraDcpOutputs {
    print("---")
    print("Processing: \(label)")
    emitUInt8(path, global, label, expand())
}

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

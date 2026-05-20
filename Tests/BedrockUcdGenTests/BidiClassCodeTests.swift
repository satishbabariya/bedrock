import Testing
@testable import BedrockUcdGen

@Suite
struct BidiClassCodeTests {

    @Test
    func everyKnownAbbreviationMapsToExpectedRaw() throws {
        let cases: [(String, UInt8)] = [
            ("L", 0), ("R", 1), ("AL", 2),
            ("EN", 3), ("ES", 4), ("ET", 5), ("AN", 6), ("CS", 7),
            ("NSM", 8), ("BN", 9),
            ("B", 10), ("S", 11), ("WS", 12), ("ON", 13),
            ("LRE", 14), ("LRO", 15), ("RLE", 16), ("RLO", 17), ("PDF", 18),
            ("LRI", 19), ("RLI", 20), ("FSI", 21), ("PDI", 22),
        ]
        for (abbr, expected) in cases {
            let actual = try BidiClassCode.rawValue(for: abbr)
            #expect(actual == expected,
                    "bidi abbreviation \(abbr) -> expected \(expected), got \(actual)")
        }
    }

    @Test
    func unknownAbbreviationThrows() {
        do {
            _ = try BidiClassCode.rawValue(for: "Zz")
            Issue.record("expected throw for unknown abbreviation")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandBidiClassTests {

    @Test
    func emptyEntriesYieldsAllLeftToRight() throws {
        let entries: [UCDEntry] = []
        let out = try entries.expandBidiClass()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func singleEntryFillsOneCodepoint() throws {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x05D0, last: 0x05D0, category: "Lo",
                     canonicalCombiningClass: 0, bidiClass: "R"),
        ]
        let out = try entries.expandBidiClass()
        #expect(out[0x05D0] == 1)
        #expect(out[0x05CF] == 0)
    }

    @Test
    func rangeEntryFillsInclusiveRange() throws {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x4E00, last: 0x9FFF, category: "Lo",
                     canonicalCombiningClass: 0, bidiClass: "L"),
        ]
        let out = try entries.expandBidiClass()
        #expect(out[0x4E00] == 0)
        #expect(out[0x6F22] == 0)
        #expect(out[0x9FFF] == 0)
    }

    @Test
    func unknownAbbreviationThrows() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0041, last: 0x0041, category: "Lu",
                     canonicalCombiningClass: 0, bidiClass: "Zz"),
        ]
        do {
            _ = try entries.expandBidiClass()
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandCanonicalCombiningClassTests {

    @Test
    func emptyEntriesYieldsAllZeros() {
        let entries: [UCDEntry] = []
        let out = entries.expandCanonicalCombiningClass()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func singleEntryFillsOneCodepoint() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0300, last: 0x0300, category: "Mn",
                     canonicalCombiningClass: 230, bidiClass: "NSM"),
        ]
        let out = entries.expandCanonicalCombiningClass()
        #expect(out[0x0300] == 230)
        #expect(out[0x02FF] == 0)
        #expect(out[0x0301] == 0)
    }

    @Test
    func rangeEntryFillsInclusiveRange() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x4E00, last: 0x9FFF, category: "Lo",
                     canonicalCombiningClass: 0, bidiClass: "L"),
        ]
        let out = entries.expandCanonicalCombiningClass()
        #expect(out[0x4E00] == 0)
        #expect(out[0x9FFF] == 0)
    }
}

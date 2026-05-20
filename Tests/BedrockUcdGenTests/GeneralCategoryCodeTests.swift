import Testing
@testable import BedrockUcdGen

@Suite
struct GeneralCategoryCodeTests {

    @Test
    func everyKnownAbbreviationMapsToExpectedRaw() throws {
        let cases: [(String, UInt8)] = [
            ("Lu", 0),  ("Ll", 1),  ("Lt", 2),  ("Lm", 3),  ("Lo", 4),
            ("Mn", 5),  ("Mc", 6),  ("Me", 7),
            ("Nd", 8),  ("Nl", 9),  ("No", 10),
            ("Pc", 11), ("Pd", 12), ("Ps", 13), ("Pe", 14),
            ("Pi", 15), ("Pf", 16), ("Po", 17),
            ("Sm", 18), ("Sc", 19), ("Sk", 20), ("So", 21),
            ("Zs", 22), ("Zl", 23), ("Zp", 24),
            ("Cc", 25), ("Cf", 26), ("Cs", 27), ("Co", 28), ("Cn", 29),
        ]
        for (abbr, expected) in cases {
            let actual = try GeneralCategoryCode.rawValue(for: abbr)
            #expect(actual == expected, "abbreviation \(abbr) -> expected \(expected), got \(actual)")
        }
    }

    @Test
    func unknownAbbreviationThrows() {
        do {
            _ = try GeneralCategoryCode.rawValue(for: "Xx")
            Issue.record("expected throw for unknown abbreviation")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandToUncompactedTests {

    @Test
    func emptyEntriesYieldsAllUnassigned() throws {
        let entries: [UCDEntry] = []
        let out = try entries.expandGeneralCategory()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 29 })
    }

    @Test
    func singleEntryFillsOneCodepoint() throws {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0041, last: 0x0041, category: "Lu"),
        ]
        let out = try entries.expandGeneralCategory()
        #expect(out[0x0041] == 0)
        #expect(out[0x0040] == 29)
        #expect(out[0x0042] == 29)
    }

    @Test
    func rangeEntryFillsInclusiveRange() throws {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x4E00, last: 0x9FFF, category: "Lo"),
        ]
        let out = try entries.expandGeneralCategory()
        #expect(out[0x4E00] == 4)
        #expect(out[0x6F22] == 4)
        #expect(out[0x9FFF] == 4)
        #expect(out[0x4DFF] == 29)
        #expect(out[0xA000] == 29)
    }

    @Test
    func unknownCategoryAbbreviationThrows() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0041, last: 0x0041, category: "Xx"),
        ]
        do {
            _ = try entries.expandGeneralCategory()
            Issue.record("expected throw for unknown category")
        } catch {
            // expected
        }
    }
}

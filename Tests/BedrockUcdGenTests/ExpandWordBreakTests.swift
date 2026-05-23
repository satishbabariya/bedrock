import Testing
@testable import BedrockUcdGen

@Suite
struct WordBreakCodeTests {

    @Test
    func allNineteenValuesMapCorrectly() throws {
        #expect(try WordBreakCode.rawValue(for: "Other")              == 0)
        #expect(try WordBreakCode.rawValue(for: "CR")                 == 1)
        #expect(try WordBreakCode.rawValue(for: "LF")                 == 2)
        #expect(try WordBreakCode.rawValue(for: "Newline")            == 3)
        #expect(try WordBreakCode.rawValue(for: "Extend")             == 4)
        #expect(try WordBreakCode.rawValue(for: "ZWJ")                == 5)
        #expect(try WordBreakCode.rawValue(for: "Regional_Indicator") == 6)
        #expect(try WordBreakCode.rawValue(for: "Format")             == 7)
        #expect(try WordBreakCode.rawValue(for: "Katakana")           == 8)
        #expect(try WordBreakCode.rawValue(for: "Hebrew_Letter")      == 9)
        #expect(try WordBreakCode.rawValue(for: "ALetter")            == 10)
        #expect(try WordBreakCode.rawValue(for: "Single_Quote")       == 11)
        #expect(try WordBreakCode.rawValue(for: "Double_Quote")       == 12)
        #expect(try WordBreakCode.rawValue(for: "MidNumLet")          == 13)
        #expect(try WordBreakCode.rawValue(for: "MidLetter")          == 14)
        #expect(try WordBreakCode.rawValue(for: "MidNum")             == 15)
        #expect(try WordBreakCode.rawValue(for: "Numeric")            == 16)
        #expect(try WordBreakCode.rawValue(for: "ExtendNumLet")       == 17)
        #expect(try WordBreakCode.rawValue(for: "WSegSpace")          == 18)
    }

    @Test
    func unknownValueThrows() {
        do {
            _ = try WordBreakCode.rawValue(for: "XX")
            Issue.record("expected throw for unknown WB value")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandWordBreakTests {

    @Test
    func emptyEntriesYieldsAllOther() throws {
        let entries: [WordBreakPropertyEntry] = []
        let out = try entries.expandWordBreak()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })   // 0 = Other (default)
    }

    @Test
    func singleCREntryFillsOneCodepoint() throws {
        let entries: [WordBreakPropertyEntry] = [
            WordBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
        ]
        let out = try entries.expandWordBreak()
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x000C] == 0)   // untouched = Other
        #expect(out[0x000E] == 0)
    }

    @Test
    func rangeALetterEntryFillsInclusiveRange() throws {
        let entries: [WordBreakPropertyEntry] = [
            WordBreakPropertyEntry(first: 0x0041, last: 0x005A, value: "ALetter"),
        ]
        let out = try entries.expandWordBreak()
        #expect(out[0x0040] == 0)   // before range = Other
        #expect(out[0x0041] == 10)  // ALetter = 10
        #expect(out[0x005A] == 10)
        #expect(out[0x005B] == 0)   // after range = Other
    }

    @Test
    func multipleEntriesWithDifferentValues() throws {
        let entries: [WordBreakPropertyEntry] = [
            WordBreakPropertyEntry(first: 0x000A, last: 0x000A, value: "LF"),
            WordBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
            WordBreakPropertyEntry(first: 0x0022, last: 0x0022, value: "Double_Quote"),
            WordBreakPropertyEntry(first: 0x0027, last: 0x0027, value: "Single_Quote"),
            WordBreakPropertyEntry(first: 0x0030, last: 0x0039, value: "Numeric"),
            WordBreakPropertyEntry(first: 0x005F, last: 0x005F, value: "ExtendNumLet"),
        ]
        let out = try entries.expandWordBreak()
        #expect(out[0x000A] == 2)   // LF = 2
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x0022] == 12)  // Double_Quote = 12
        #expect(out[0x0027] == 11)  // Single_Quote = 11
        #expect(out[0x0030] == 16)  // Numeric = 16
        #expect(out[0x0039] == 16)  // Numeric = 16
        #expect(out[0x005F] == 17)  // ExtendNumLet = 17
    }

    @Test
    func unknownValueInEntryThrows() {
        let entries: [WordBreakPropertyEntry] = [
            WordBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "XX"),
        ]
        do {
            _ = try entries.expandWordBreak()
            Issue.record("expected throw for unknown WB value")
        } catch {
            // expected
        }
    }
}

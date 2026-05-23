import Testing
@testable import BedrockUcdGen

@Suite
struct SentenceBreakCodeTests {

    @Test
    func allFifteenValuesMapCorrectly() throws {
        #expect(try SentenceBreakCode.rawValue(for: "Other")     == 0)
        #expect(try SentenceBreakCode.rawValue(for: "CR")        == 1)
        #expect(try SentenceBreakCode.rawValue(for: "LF")        == 2)
        #expect(try SentenceBreakCode.rawValue(for: "Sep")       == 3)
        #expect(try SentenceBreakCode.rawValue(for: "Extend")    == 4)
        #expect(try SentenceBreakCode.rawValue(for: "Format")    == 5)
        #expect(try SentenceBreakCode.rawValue(for: "Sp")        == 6)
        #expect(try SentenceBreakCode.rawValue(for: "Lower")     == 7)
        #expect(try SentenceBreakCode.rawValue(for: "Upper")     == 8)
        #expect(try SentenceBreakCode.rawValue(for: "OLetter")   == 9)
        #expect(try SentenceBreakCode.rawValue(for: "Numeric")   == 10)
        #expect(try SentenceBreakCode.rawValue(for: "ATerm")     == 11)
        #expect(try SentenceBreakCode.rawValue(for: "STerm")     == 12)
        #expect(try SentenceBreakCode.rawValue(for: "SContinue") == 13)
        #expect(try SentenceBreakCode.rawValue(for: "Close")     == 14)
    }

    @Test
    func unknownValueThrows() {
        do {
            _ = try SentenceBreakCode.rawValue(for: "XX")
            Issue.record("expected throw for unknown SB value")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandSentenceBreakTests {

    @Test
    func emptyEntriesYieldsAllOther() throws {
        let entries: [SentenceBreakPropertyEntry] = []
        let out = try entries.expandSentenceBreak()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })   // 0 = Other (default)
    }

    @Test
    func singleCREntryFillsOneCodepoint() throws {
        let entries: [SentenceBreakPropertyEntry] = [
            SentenceBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
        ]
        let out = try entries.expandSentenceBreak()
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x000C] == 0)   // untouched = Other
        #expect(out[0x000E] == 0)
    }

    @Test
    func rangeUpperEntryFillsInclusiveRange() throws {
        let entries: [SentenceBreakPropertyEntry] = [
            SentenceBreakPropertyEntry(first: 0x0041, last: 0x005A, value: "Upper"),
        ]
        let out = try entries.expandSentenceBreak()
        #expect(out[0x0040] == 0)   // before range = Other
        #expect(out[0x0041] == 8)   // Upper = 8
        #expect(out[0x004D] == 8)
        #expect(out[0x005A] == 8)
        #expect(out[0x005B] == 0)   // after range = Other
    }

    @Test
    func multipleEntriesWithDifferentValues() throws {
        let entries: [SentenceBreakPropertyEntry] = [
            SentenceBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
            SentenceBreakPropertyEntry(first: 0x000A, last: 0x000A, value: "LF"),
            SentenceBreakPropertyEntry(first: 0x0085, last: 0x0085, value: "Sep"),
            SentenceBreakPropertyEntry(first: 0x0020, last: 0x0020, value: "Sp"),
            SentenceBreakPropertyEntry(first: 0x002E, last: 0x002E, value: "ATerm"),
            SentenceBreakPropertyEntry(first: 0x0021, last: 0x0021, value: "STerm"),
        ]
        let out = try entries.expandSentenceBreak()
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x000A] == 2)   // LF = 2
        #expect(out[0x0085] == 3)   // Sep = 3
        #expect(out[0x0020] == 6)   // Sp = 6
        #expect(out[0x002E] == 11)  // ATerm = 11
        #expect(out[0x0021] == 12)  // STerm = 12
    }

    @Test
    func unknownValueInEntryThrows() {
        let entries: [SentenceBreakPropertyEntry] = [
            SentenceBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "XX"),
        ]
        do {
            _ = try entries.expandSentenceBreak()
            Issue.record("expected throw for unknown SB value")
        } catch {
            // expected
        }
    }
}

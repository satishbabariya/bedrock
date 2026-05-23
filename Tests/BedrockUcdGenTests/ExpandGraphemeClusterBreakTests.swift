import Testing
@testable import BedrockUcdGen

@Suite
struct GraphemeClusterBreakCodeTests {

    @Test
    func allFourteenValuesMapCorrectly() throws {
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Other")              == 0)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "CR")                 == 1)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "LF")                 == 2)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Control")            == 3)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Extend")             == 4)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "ZWJ")                == 5)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Regional_Indicator") == 6)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "Prepend")            == 7)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "SpacingMark")        == 8)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "L")                  == 9)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "V")                  == 10)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "T")                  == 11)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "LV")                 == 12)
        #expect(try GraphemeClusterBreakCode.rawValue(for: "LVT")                == 13)
    }

    @Test
    func unknownValueThrows() {
        do {
            _ = try GraphemeClusterBreakCode.rawValue(for: "XX")
            Issue.record("expected throw for unknown GCB value")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandGraphemeClusterBreakTests {

    @Test
    func emptyEntriesYieldsAllOther() throws {
        let entries: [GraphemeBreakPropertyEntry] = []
        let out = try entries.expandGraphemeClusterBreak()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })   // 0 = Other (default)
    }

    @Test
    func singleCREntryFillsOneCodepoint() throws {
        let entries: [GraphemeBreakPropertyEntry] = [
            GraphemeBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
        ]
        let out = try entries.expandGraphemeClusterBreak()
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x000C] == 0)   // untouched = Other
        #expect(out[0x000E] == 0)
    }

    @Test
    func rangeExtendEntryFillsInclusiveRange() throws {
        let entries: [GraphemeBreakPropertyEntry] = [
            GraphemeBreakPropertyEntry(first: 0x0300, last: 0x0302, value: "Extend"),
        ]
        let out = try entries.expandGraphemeClusterBreak()
        #expect(out[0x02FF] == 0)   // before range = Other
        #expect(out[0x0300] == 4)   // Extend = 4
        #expect(out[0x0301] == 4)
        #expect(out[0x0302] == 4)
        #expect(out[0x0303] == 0)   // after range = Other
    }

    @Test
    func multipleEntriesWithDifferentValues() throws {
        let entries: [GraphemeBreakPropertyEntry] = [
            GraphemeBreakPropertyEntry(first: 0x000A, last: 0x000A, value: "LF"),
            GraphemeBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "CR"),
            GraphemeBreakPropertyEntry(first: 0x1100, last: 0x1100, value: "L"),
            GraphemeBreakPropertyEntry(first: 0x1160, last: 0x1160, value: "V"),
            GraphemeBreakPropertyEntry(first: 0x11A8, last: 0x11A8, value: "T"),
            GraphemeBreakPropertyEntry(first: 0xAC00, last: 0xAC00, value: "LV"),
            GraphemeBreakPropertyEntry(first: 0xAC01, last: 0xAC01, value: "LVT"),
        ]
        let out = try entries.expandGraphemeClusterBreak()
        #expect(out[0x000A] == 2)   // LF = 2
        #expect(out[0x000D] == 1)   // CR = 1
        #expect(out[0x1100] == 9)   // L = 9
        #expect(out[0x1160] == 10)  // V = 10
        #expect(out[0x11A8] == 11)  // T = 11
        #expect(out[0xAC00] == 12)  // LV = 12
        #expect(out[0xAC01] == 13)  // LVT = 13
    }

    @Test
    func unknownValueInEntryThrows() {
        let entries: [GraphemeBreakPropertyEntry] = [
            GraphemeBreakPropertyEntry(first: 0x000D, last: 0x000D, value: "XX"),
        ]
        do {
            _ = try entries.expandGraphemeClusterBreak()
            Issue.record("expected throw for unknown GCB value")
        } catch {
            // expected
        }
    }
}

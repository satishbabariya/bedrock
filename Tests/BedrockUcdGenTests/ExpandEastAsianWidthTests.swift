import Testing
@testable import BedrockUcdGen

@Suite
struct EastAsianWidthCodeTests {

    @Test
    func allSixCodesMapCorrectly() throws {
        #expect(try EastAsianWidthCode.rawValue(for: "Na") == 0)
        #expect(try EastAsianWidthCode.rawValue(for: "W")  == 1)
        #expect(try EastAsianWidthCode.rawValue(for: "H")  == 2)
        #expect(try EastAsianWidthCode.rawValue(for: "F")  == 3)
        #expect(try EastAsianWidthCode.rawValue(for: "A")  == 4)
        #expect(try EastAsianWidthCode.rawValue(for: "N")  == 5)
    }

    @Test
    func unknownCodeThrows() {
        do {
            _ = try EastAsianWidthCode.rawValue(for: "X")
            Issue.record("expected throw for unknown code")
        } catch {
            // expected
        }
    }
}

@Suite
struct ExpandEastAsianWidthTests {

    @Test
    func emptyEntriesYieldsAllNeutral() throws {
        let entries: [EastAsianWidthEntry] = []
        let out = try entries.expandEastAsianWidth()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 5 })   // 5 = N (Neutral), the default
    }

    @Test
    func singleCodepointEntryFillsCorrectly() throws {
        let entries: [EastAsianWidthEntry] = [
            EastAsianWidthEntry(first: 0x0020, last: 0x0020, value: "Na"),
        ]
        let out = try entries.expandEastAsianWidth()
        #expect(out[0x0020] == 0)   // Na = 0
        #expect(out[0x001F] == 5)   // untouched = N
        #expect(out[0x0021] == 5)
    }

    @Test
    func rangeEntryFillsInclusiveRange() throws {
        let entries: [EastAsianWidthEntry] = [
            EastAsianWidthEntry(first: 0x3001, last: 0x3003, value: "W"),
        ]
        let out = try entries.expandEastAsianWidth()
        #expect(out[0x3000] == 5)   // before range
        #expect(out[0x3001] == 1)   // W = 1
        #expect(out[0x3002] == 1)
        #expect(out[0x3003] == 1)
        #expect(out[0x3004] == 5)   // after range
    }

    @Test
    func multipleEntriesWithDifferentCodes() throws {
        let entries: [EastAsianWidthEntry] = [
            EastAsianWidthEntry(first: 0x0000, last: 0x001F, value: "N"),
            EastAsianWidthEntry(first: 0x0020, last: 0x0020, value: "Na"),
            EastAsianWidthEntry(first: 0x3000, last: 0x3000, value: "F"),
            EastAsianWidthEntry(first: 0x3001, last: 0x3003, value: "W"),
            EastAsianWidthEntry(first: 0xFF71, last: 0xFF71, value: "H"),
            EastAsianWidthEntry(first: 0x0391, last: 0x0391, value: "A"),
        ]
        let out = try entries.expandEastAsianWidth()
        #expect(out[0x0000] == 5)   // N = 5
        #expect(out[0x0020] == 0)   // Na = 0
        #expect(out[0x3000] == 3)   // F = 3
        #expect(out[0x3001] == 1)   // W = 1
        #expect(out[0xFF71] == 2)   // H = 2
        #expect(out[0x0391] == 4)   // A = 4
    }

    @Test
    func unknownCodeInEntryThrows() {
        let entries: [EastAsianWidthEntry] = [
            EastAsianWidthEntry(first: 0x0020, last: 0x0020, value: "X"),
        ]
        do {
            _ = try entries.expandEastAsianWidth()
            Issue.record("expected throw for unknown EAW code")
        } catch {
            // expected
        }
    }
}

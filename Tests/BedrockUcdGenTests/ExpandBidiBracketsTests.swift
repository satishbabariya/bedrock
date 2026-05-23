import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandBidiBracketsTests {

    @Test
    func emptyEntriesYieldsAllZeroTypeTable() {
        let entries: [BidiBracketEntry] = []
        let out = entries.expandBidiBracketType()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func emptyEntriesYieldsAllZeroPairedTable() {
        let entries: [BidiBracketEntry] = []
        let out = entries.expandBidiPairedBracket()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func openEntryWritesOneAndPaired() {
        let entries: [BidiBracketEntry] = [
            BidiBracketEntry(codepoint: 0x0028,
                             pairedCodepoint: 0x0029,
                             type: .open),
        ]
        let typeOut   = entries.expandBidiBracketType()
        let pairedOut = entries.expandBidiPairedBracket()
        #expect(typeOut[0x0028]   == 1)          // open = 1
        #expect(typeOut[0x0029]   == 0)          // untouched
        #expect(pairedOut[0x0028] == 0x0029)     // paired codepoint
        #expect(pairedOut[0x0029] == 0)          // untouched
    }

    @Test
    func closeEntryWritesTwoAndPaired() {
        let entries: [BidiBracketEntry] = [
            BidiBracketEntry(codepoint: 0x0029,
                             pairedCodepoint: 0x0028,
                             type: .close),
        ]
        let typeOut   = entries.expandBidiBracketType()
        let pairedOut = entries.expandBidiPairedBracket()
        #expect(typeOut[0x0029]   == 2)          // close = 2
        #expect(typeOut[0x0028]   == 0)          // untouched
        #expect(pairedOut[0x0029] == 0x0028)     // paired codepoint
        #expect(pairedOut[0x0028] == 0)          // untouched
    }

    @Test
    func multipleEntriesSetDistinctIndices() {
        let entries: [BidiBracketEntry] = [
            BidiBracketEntry(codepoint: 0x0028, pairedCodepoint: 0x0029, type: .open),
            BidiBracketEntry(codepoint: 0x0029, pairedCodepoint: 0x0028, type: .close),
            BidiBracketEntry(codepoint: 0x005B, pairedCodepoint: 0x005D, type: .open),
            BidiBracketEntry(codepoint: 0x005D, pairedCodepoint: 0x005B, type: .close),
        ]
        let typeOut   = entries.expandBidiBracketType()
        let pairedOut = entries.expandBidiPairedBracket()

        #expect(typeOut[0x0028]   == 1)
        #expect(typeOut[0x0029]   == 2)
        #expect(typeOut[0x005B]   == 1)
        #expect(typeOut[0x005D]   == 2)
        #expect(typeOut[0x0041]   == 0)          // 'A' — not a bracket

        #expect(pairedOut[0x0028] == 0x0029)
        #expect(pairedOut[0x0029] == 0x0028)
        #expect(pairedOut[0x005B] == 0x005D)
        #expect(pairedOut[0x005D] == 0x005B)
        #expect(pairedOut[0x0041] == 0)
    }
}

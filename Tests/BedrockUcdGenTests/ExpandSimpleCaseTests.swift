import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandSimpleUppercaseTests {

    @Test
    func emptyEntriesYieldsAllZeros() {
        let entries: [UCDEntry] = []
        let out = entries.expandSimpleUppercase()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func entryWithMappingFillsOneCodepoint() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0061, last: 0x0061, category: "Ll",
                     simpleUppercase: 0x0041),
        ]
        let out = entries.expandSimpleUppercase()
        #expect(out[0x0061] == 0x0041)
        #expect(out[0x0060] == 0)
        #expect(out[0x0062] == 0)
    }

    @Test
    func entryWithoutMappingStaysAtZero() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0041, last: 0x0041, category: "Lu",
                     simpleUppercase: 0),
        ]
        let out = entries.expandSimpleUppercase()
        #expect(out[0x0041] == 0)
    }

    @Test
    func rangeEntryWithoutMappingLeavesRangeZero() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x4E00, last: 0x9FFF, category: "Lo",
                     simpleUppercase: 0),
        ]
        let out = entries.expandSimpleUppercase()
        #expect(out[0x4E00] == 0)
        #expect(out[0x6F22] == 0)
        #expect(out[0x9FFF] == 0)
    }
}

@Suite
struct ExpandSimpleLowercaseTests {

    @Test
    func entryWithMappingFillsOneCodepoint() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x0041, last: 0x0041, category: "Lu",
                     simpleLowercase: 0x0061),
        ]
        let out = entries.expandSimpleLowercase()
        #expect(out[0x0041] == 0x0061)
        #expect(out[0x0040] == 0)
    }
}

@Suite
struct ExpandSimpleTitlecaseTests {

    @Test
    func entryWithMappingFillsOneCodepoint() {
        let entries: [UCDEntry] = [
            UCDEntry(first: 0x01C5, last: 0x01C5, category: "Lt",
                     simpleTitlecase: 0x01C5),
        ]
        let out = entries.expandSimpleTitlecase()
        #expect(out[0x01C5] == 0x01C5)
    }
}

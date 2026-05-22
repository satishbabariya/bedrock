import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandFullCaseFoldingTests {

    @Test
    func emptyEntriesYieldsSentinelOnlyFlat() {
        let entries: [CaseFoldingEntry] = []
        let (index, flat) = entries.expandFullCaseFolding()
        #expect(index.count == 0x110000)
        #expect(index.allSatisfy { $0 == 0 })
        #expect(flat == [0])
    }

    @Test
    func singleCommonEntryProducesLengthOne() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let packed = index[0x0041]
        let offset = Int(packed >> 8)
        let length = Int(packed & 0xFF)
        #expect(length == 1)
        #expect(offset == 1)
        #expect(flat[offset] == 0x0061)
        #expect(flat == [0, 0x0061])
    }

    @Test
    func singleFullEntryWithTwoCodepoints() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x00DF, status: .full,
                              mapping: [0x0073, 0x0073]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let packed = index[0x00DF]
        let offset = Int(packed >> 8)
        let length = Int(packed & 0xFF)
        #expect(length == 2)
        #expect(offset == 1)
        #expect(flat[offset] == 0x0073)
        #expect(flat[offset + 1] == 0x0073)
        #expect(flat == [0, 0x0073, 0x0073])
    }

    @Test
    func singleFullEntryWithThreeCodepoints() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0xFB03, status: .full,
                              mapping: [0x0066, 0x0066, 0x0069]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let packed = index[0xFB03]
        let length = Int(packed & 0xFF)
        let offset = Int(packed >> 8)
        #expect(length == 3)
        #expect(offset == 1)
        #expect(flat == [0, 0x0066, 0x0066, 0x0069])
    }

    @Test
    func fullOverridesCommonOnSameCodepoint() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
            CaseFoldingEntry(codepoint: 0x0041, status: .full,
                              mapping: [0x0061, 0x0301]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let packed = index[0x0041]
        let offset = Int(packed >> 8)
        let length = Int(packed & 0xFF)
        #expect(length == 2)
        #expect(flat[offset] == 0x0061)
        #expect(flat[offset + 1] == 0x0301)
    }

    @Test
    func simpleAndTurkicEntriesAreSkipped() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x1E9E, status: .simple, mapping: [0x00DF]),
            CaseFoldingEntry(codepoint: 0x0130, status: .turkic, mapping: [0x0069]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        #expect(index[0x1E9E] == 0)
        #expect(index[0x0130] == 0)
        #expect(flat == [0])
    }

    @Test
    func multipleFullEntriesGetDistinctOffsets() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x00DF, status: .full,
                              mapping: [0x0073, 0x0073]),
            CaseFoldingEntry(codepoint: 0x0130, status: .full,
                              mapping: [0x0069, 0x0307]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        let p1 = index[0x00DF]
        let p2 = index[0x0130]
        let o1 = Int(p1 >> 8)
        let o2 = Int(p2 >> 8)
        #expect(o1 != o2)
        #expect(p1 & 0xFF == 2)
        #expect(p2 & 0xFF == 2)
        #expect(flat == [0, 0x0073, 0x0073, 0x0069, 0x0307])
    }

    @Test
    func mixedRealisticInput() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
            CaseFoldingEntry(codepoint: 0x00DF, status: .full,
                              mapping: [0x0073, 0x0073]),
            CaseFoldingEntry(codepoint: 0x0130, status: .full,
                              mapping: [0x0069, 0x0307]),
            CaseFoldingEntry(codepoint: 0x0130, status: .turkic, mapping: [0x0069]),
            CaseFoldingEntry(codepoint: 0x1E9E, status: .simple, mapping: [0x00DF]),
        ]
        let (index, flat) = entries.expandFullCaseFolding()
        #expect(index[0x0041] != 0)
        #expect(index[0x00DF] != 0)
        #expect(index[0x0130] != 0)
        #expect(index[0x1E9E] == 0)
        #expect(flat == [0, 0x0061, 0x0073, 0x0073, 0x0069, 0x0307])
    }
}

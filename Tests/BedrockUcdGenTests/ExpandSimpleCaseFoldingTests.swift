import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandSimpleCaseFoldingTests {

    @Test
    func emptyEntriesYieldsAllZeros() {
        let entries: [CaseFoldingEntry] = []
        let out = entries.expandSimpleCaseFolding()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func singleCommonEntryFillsOneCodepoint() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0041] == 0x0061)
        #expect(out[0x0040] == 0)
        #expect(out[0x0042] == 0)
    }

    @Test
    func singleSimpleEntryFillsOneCodepoint() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x1E9E, status: .simple, mapping: [0x00DF]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x1E9E] == 0x00DF)
    }

    @Test
    func fullEntryIsSkipped() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x00DF, status: .full, mapping: [0x0073, 0x0073]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x00DF] == 0)
    }

    @Test
    func turkicEntryIsSkipped() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0130, status: .turkic, mapping: [0x0069]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0130] == 0)
    }

    @Test
    func multiCodepointCommonMappingIsDefensivelySkipped() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common,
                              mapping: [0x0061, 0x0062]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0041] == 0)
    }

    @Test
    func simpleOverridesCommonOnSameCodepoint() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
            CaseFoldingEntry(codepoint: 0x0041, status: .simple, mapping: [0x0062]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0041] == 0x0062)
    }

    @Test
    func mixedRealisticInput() {
        let entries: [CaseFoldingEntry] = [
            CaseFoldingEntry(codepoint: 0x0041, status: .common, mapping: [0x0061]),
            CaseFoldingEntry(codepoint: 0x00DF, status: .full,   mapping: [0x0073, 0x0073]),
            CaseFoldingEntry(codepoint: 0x0130, status: .full,   mapping: [0x0069, 0x0307]),
            CaseFoldingEntry(codepoint: 0x0130, status: .turkic, mapping: [0x0069]),
            CaseFoldingEntry(codepoint: 0x1E9E, status: .simple, mapping: [0x00DF]),
        ]
        let out = entries.expandSimpleCaseFolding()
        #expect(out[0x0041] == 0x0061)
        #expect(out[0x00DF] == 0)
        #expect(out[0x0130] == 0)
        #expect(out[0x1E9E] == 0x00DF)
    }
}

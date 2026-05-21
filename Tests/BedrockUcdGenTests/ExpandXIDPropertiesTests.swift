import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandXIDStartTests {

    @Test
    func emptyEntriesYieldsAllZeros() {
        let entries: [DerivedCorePropertyEntry] = []
        let out = entries.expandXIDStart()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    @Test
    func singleCodepointEntrySetsOne() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x0041,
                                       propertyName: "XID_Start"),
        ]
        let out = entries.expandXIDStart()
        #expect(out[0x0041] == 1)
        #expect(out[0x0040] == 0)
        #expect(out[0x0042] == 0)
    }

    @Test
    func rangeEntryFillsInclusiveRange() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x005A,
                                       propertyName: "XID_Start"),
        ]
        let out = entries.expandXIDStart()
        #expect(out[0x0040] == 0)
        #expect(out[0x0041] == 1)
        #expect(out[0x0050] == 1)
        #expect(out[0x005A] == 1)
        #expect(out[0x005B] == 0)
    }

    @Test
    func entryWithDifferentPropertyIsSkipped() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x0041,
                                       propertyName: "Math"),
        ]
        let out = entries.expandXIDStart()
        #expect(out[0x0041] == 0)
    }
}

@Suite
struct ExpandXIDContinueTests {

    @Test
    func picksUpOnlyXIDContinue() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x005A,
                                       propertyName: "XID_Start"),
            DerivedCorePropertyEntry(first: 0x005F, last: 0x005F,
                                       propertyName: "XID_Continue"),
            DerivedCorePropertyEntry(first: 0x002B, last: 0x002B,
                                       propertyName: "Math"),
        ]
        let out = entries.expandXIDContinue()
        #expect(out[0x0041] == 0)
        #expect(out[0x005F] == 1)
        #expect(out[0x002B] == 0)
    }

    @Test
    func startAndContinueOnSameRangeAreIndependent() {
        let entries: [DerivedCorePropertyEntry] = [
            DerivedCorePropertyEntry(first: 0x0041, last: 0x005A,
                                       propertyName: "XID_Start"),
            DerivedCorePropertyEntry(first: 0x0041, last: 0x005A,
                                       propertyName: "XID_Continue"),
        ]
        let startOut = entries.expandXIDStart()
        let contOut = entries.expandXIDContinue()
        #expect(startOut[0x0041] == 1)
        #expect(contOut[0x0041] == 1)
    }
}

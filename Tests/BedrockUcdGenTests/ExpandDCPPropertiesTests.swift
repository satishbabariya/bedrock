import Testing
@testable import BedrockUcdGen

@Suite
struct ExpandDCPPropertiesTests {

    // MARK: - Shared helpers

    private func entries(_ pairs: [(UInt32, UInt32, String)]) -> [DerivedCorePropertyEntry] {
        pairs.map { DerivedCorePropertyEntry(first: $0.0, last: $0.1, propertyName: $0.2) }
    }

    // MARK: - expandIDStart

    @Test
    func expandIDStart_filtersCorrectly() {
        let e = entries([
            (0x0041, 0x005A, "ID_Start"),
            (0x0041, 0x005A, "XID_Start"),
            (0x002B, 0x002B, "Math"),
        ])
        let out = e.expandIDStart()
        #expect(out[0x0041] == 1)
        #expect(out[0x005A] == 1)
        #expect(out[0x002B] == 0)   // Math, not ID_Start
    }

    @Test
    func expandIDStart_emptyYieldsAllZeros() {
        let out = entries([]).expandIDStart()
        #expect(out.count == 0x110000)
        #expect(out.allSatisfy { $0 == 0 })
    }

    // MARK: - expandIDContinue

    @Test
    func expandIDContinue_filtersCorrectly() {
        let e = entries([
            (0x005F, 0x005F, "ID_Continue"),
            (0x0030, 0x0039, "ID_Continue"),
            (0x0030, 0x0039, "ID_Start"),  // same range, different prop
        ])
        let out = e.expandIDContinue()
        #expect(out[0x005F] == 1)
        #expect(out[0x0030] == 1)
        #expect(out[0x0039] == 1)
    }

    // MARK: - expandMath

    @Test
    func expandMath_filtersCorrectly() {
        let e = entries([
            (0x002B, 0x002B, "Math"),
            (0x003C, 0x003E, "Math"),
            (0x0041, 0x0041, "ID_Start"),
        ])
        let out = e.expandMath()
        #expect(out[0x002B] == 1)
        #expect(out[0x003C] == 1)
        #expect(out[0x003E] == 1)
        #expect(out[0x0041] == 0)
    }

    // MARK: - expandAlphabetic

    @Test
    func expandAlphabetic_filtersCorrectly() {
        let e = entries([
            (0x0041, 0x005A, "Alphabetic"),
            (0x0030, 0x0039, "ID_Continue"),  // digits — not Alphabetic
        ])
        let out = e.expandAlphabetic()
        #expect(out[0x0041] == 1)
        #expect(out[0x005A] == 1)
        #expect(out[0x0030] == 0)
    }

    // MARK: - expandCased

    @Test
    func expandCased_filtersCorrectly() {
        let e = entries([
            (0x0041, 0x005A, "Cased"),   // uppercase Latin
            (0x0061, 0x007A, "Cased"),   // lowercase Latin
            (0x0030, 0x0039, "ID_Continue"),
        ])
        let out = e.expandCased()
        #expect(out[0x0041] == 1)
        #expect(out[0x0061] == 1)
        #expect(out[0x0030] == 0)
    }

    // MARK: - expandLowercase

    @Test
    func expandLowercase_filtersCorrectly() {
        let e = entries([
            (0x0061, 0x007A, "Lowercase"),
            (0x0041, 0x005A, "Uppercase"),
            (0x0041, 0x005A, "Cased"),
        ])
        let out = e.expandLowercase()
        #expect(out[0x0061] == 1)
        #expect(out[0x007A] == 1)
        #expect(out[0x0041] == 0)   // Uppercase, not Lowercase
    }

    // MARK: - expandUppercase

    @Test
    func expandUppercase_filtersCorrectly() {
        let e = entries([
            (0x0041, 0x005A, "Uppercase"),
            (0x0061, 0x007A, "Lowercase"),
        ])
        let out = e.expandUppercase()
        #expect(out[0x0041] == 1)
        #expect(out[0x005A] == 1)
        #expect(out[0x0061] == 0)   // Lowercase, not Uppercase
    }

    // MARK: - Cross-property isolation

    @Test
    func eachHelperIgnoresAllOtherProperties() {
        // A single entry with each of the 7 new property names.
        let e = entries([
            (0x0001, 0x0001, "ID_Start"),
            (0x0002, 0x0002, "ID_Continue"),
            (0x0003, 0x0003, "Math"),
            (0x0004, 0x0004, "Alphabetic"),
            (0x0005, 0x0005, "Cased"),
            (0x0006, 0x0006, "Lowercase"),
            (0x0007, 0x0007, "Uppercase"),
        ])
        #expect(e.expandIDStart()[0x0001] == 1)
        #expect(e.expandIDStart()[0x0002] == 0)
        #expect(e.expandIDStart()[0x0003] == 0)

        #expect(e.expandIDContinue()[0x0002] == 1)
        #expect(e.expandIDContinue()[0x0001] == 0)

        #expect(e.expandMath()[0x0003] == 1)
        #expect(e.expandMath()[0x0001] == 0)

        #expect(e.expandAlphabetic()[0x0004] == 1)
        #expect(e.expandAlphabetic()[0x0003] == 0)

        #expect(e.expandCased()[0x0005] == 1)
        #expect(e.expandCased()[0x0004] == 0)

        #expect(e.expandLowercase()[0x0006] == 1)
        #expect(e.expandLowercase()[0x0005] == 0)

        #expect(e.expandUppercase()[0x0007] == 1)
        #expect(e.expandUppercase()[0x0006] == 0)
    }
}

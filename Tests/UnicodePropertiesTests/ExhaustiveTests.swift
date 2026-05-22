import Testing
import UnicodeProperties

@Suite
struct ExhaustiveTests {

    @Test
    func everyCodepointLookupCompletesAndReturnsValidValue() {
        for cp: UInt32 in 0 ..< 0x110000 {
            guard let scalar = Unicode.Scalar(cp) else { continue }
            let c = UnicodeProperties.generalCategory(of: scalar)
            #expect(c.rawValue <= 29,
                    "out-of-range raw value at U+\(String(cp, radix: 16))")
            let b = UnicodeProperties.bidiClass(of: scalar)
            #expect(b.rawValue <= 22,
                    "out-of-range bidi-class raw value at U+\(String(cp, radix: 16))")
            _ = UnicodeProperties.canonicalCombiningClass(of: scalar)
            _ = UnicodeProperties.simpleUppercase(of: scalar)
            _ = UnicodeProperties.simpleLowercase(of: scalar)
            _ = UnicodeProperties.simpleTitlecase(of: scalar)
            _ = UnicodeProperties.caseFolded(of: scalar)
            _ = UnicodeProperties.isXIDStart(scalar)
            _ = UnicodeProperties.isXIDContinue(scalar)
            _ = UnicodeProperties.fullCaseFolded(of: scalar)
        }
    }
}

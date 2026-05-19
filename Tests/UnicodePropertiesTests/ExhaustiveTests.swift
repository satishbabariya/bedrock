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
        }
    }
}

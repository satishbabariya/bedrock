import Testing
import Bytes
@testable import Base64

@Test func extensionEncodeOnBytes() {
    let b = Bytes(Array("foo".utf8))
    #expect(b.base64Encoded() == "Zm9v")
    #expect(b.base64Encoded(variant: .urlSafe) == "Zm9v")
    #expect(b.base64Encoded(padding: false) == "Zm9v")
}

@Test func extensionStringBase64Encoding() {
    let b = Bytes(Array("foo".utf8))
    #expect(String(base64Encoding: b) == "Zm9v")
}

@Test func extensionBytesBase64Decoding() throws {
    let b = try Bytes(base64Decoding: "Zm9v")
    #expect(Array(b) == Array("foo".utf8))
}

@Test func roundTripEveryLengthThrough256() throws {
    // For each length 0...256, encode and decode under each variant +
    // padding setting, asserting the round-trip is identity.
    for length in 0...256 {
        let arr = (0..<length).map { UInt8($0 & 0xFF) }
        let original = Bytes(arr)
        for variant in [Base64.Variant.standard, .urlSafe] {
            for padding in [true, false] {
                let encoded = Base64.encode(original, variant: variant, padding: padding)
                let decoded = try Base64.decode(encoded)
                #expect(original == decoded,
                        "round-trip failed: length=\(length) variant=\(variant) padding=\(padding)")
            }
        }
    }
}

@Test func roundTripDeterministicRandom() throws {
    var state: UInt64 = 0x0123456789ABCDEF
    func next() -> UInt8 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8((state >> 56) & 0xFF)
    }
    var arr: [UInt8] = []
    arr.reserveCapacity(4096)
    for _ in 0..<4096 { arr.append(next()) }
    let original = Bytes(arr)

    for variant in [Base64.Variant.standard, .urlSafe] {
        for padding in [true, false] {
            let encoded = Base64.encode(original, variant: variant, padding: padding)
            let decoded = try Base64.decode(encoded)
            #expect(original == decoded)
        }
    }
}

@Test func roundTripLenientAndConstantTimeModes() throws {
    // Use a small but representative payload across all valid lengths.
    for length in 0...32 {
        let arr = (0..<length).map { UInt8($0 & 0xFF) }
        let original = Bytes(arr)

        // Encode with both variants x padding settings, then decode under
        // .lenient and .constantTime. Both should yield identity round-trips
        // when input is well-formed (no whitespace).
        for variant in [Base64.Variant.standard, .urlSafe] {
            for padding in [true, false] {
                let encoded = Base64.encode(original, variant: variant, padding: padding)

                let viaLenient = try Base64.decode(encoded, mode: .lenient)
                #expect(original == viaLenient,
                        "lenient round-trip failed: length=\(length) variant=\(variant) padding=\(padding)")

                let viaConstantTime = try Base64.decode(encoded, mode: .constantTime)
                #expect(original == viaConstantTime,
                        "constantTime round-trip failed: length=\(length) variant=\(variant) padding=\(padding)")
            }
        }
    }
}

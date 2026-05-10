import Testing
import Bytes
@testable import Hex

@Test func extensionEncodeOnBytes() {
    let b = Bytes([0xDE, 0xAD])
    #expect(b.hexEncoded() == "dead")
    #expect(b.hexEncoded(case: .upper) == "DEAD")
}

@Test func extensionStringHexEncoding() {
    let b = Bytes([0xCA, 0xFE])
    #expect(String(hexEncoding: b) == "cafe")
    #expect(String(hexEncoding: b, case: .upper) == "CAFE")
}

@Test func extensionBytesHexDecoding() throws {
    let b = try Bytes(hexDecoding: "deadbeef")
    #expect(Array(b) == [0xDE, 0xAD, 0xBE, 0xEF])
}

@Test func roundTripEveryByte() throws {
    var arr: [UInt8] = []
    for i in 0..<256 { arr.append(UInt8(i)) }
    let original = Bytes(arr)
    let lower = original.hexEncoded()
    let upper = original.hexEncoded(case: .upper)
    let backFromLower = try Bytes(hexDecoding: lower)
    let backFromUpper = try Bytes(hexDecoding: upper)
    #expect(original == backFromLower)
    #expect(original == backFromUpper)
}

@Test func roundTripDeterministicRandom() throws {
    // Linear congruential generator with fixed seed for repeatability.
    var state: UInt64 = 0xDEADBEEFCAFEBABE
    func next() -> UInt8 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8((state >> 56) & 0xFF)
    }
    var arr: [UInt8] = []
    arr.reserveCapacity(4096)
    for _ in 0..<4096 { arr.append(next()) }
    let original = Bytes(arr)
    let encoded = original.hexEncoded()
    let decoded = try Bytes(hexDecoding: encoded)
    #expect(original == decoded)
}

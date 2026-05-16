import Testing
import Bytes
@testable import PercentEncoding

@Test func roundTripEveryByteThroughComponent() throws {
    let raw: [UInt8] = (0..<256).map { UInt8($0) }
    let original = Bytes(raw)
    let encoded = PercentEncoding.encode(original, as: .component)
    let decoded = try PercentEncoding.decode(encoded)
    #expect(decoded == original)
}

@Test func roundTripEveryByteThroughForm() throws {
    let raw: [UInt8] = (0..<256).map { UInt8($0) }
    let original = Bytes(raw)
    let encoded = PercentEncoding.encode(original, as: .form)
    let decoded = try PercentEncoding.decodeForm(encoded)
    #expect(decoded == original)
}

@Test func roundTripDeterministicRandom() throws {
    var state: UInt64 = 0xC0FFEE_FACE_F00D
    func next() -> UInt8 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8((state >> 56) & 0xFF)
    }
    var arr: [UInt8] = []
    arr.reserveCapacity(4096)
    for _ in 0..<4096 { arr.append(next()) }
    let original = Bytes(arr)
    let encoded = PercentEncoding.encode(original, as: .component)
    let decoded = try PercentEncoding.decode(encoded)
    #expect(decoded == original)
}

@Test func roundTripEverySet() throws {
    // Mixed input that exercises both safe and unsafe bytes for every set.
    let original = Bytes(Array("Hello World!/?&=:@#".utf8))
    for set in [PercentEncoding.Set.unreserved, .pathSegment, .query, .fragment, .userinfo, .component] {
        let encoded = PercentEncoding.encode(original, as: set)
        let decoded = try PercentEncoding.decode(encoded)
        #expect(decoded == original, "round-trip failed for set: \(set)")
    }
    // .form needs decodeForm:
    let encodedForm = PercentEncoding.encode(original, as: .form)
    let decodedForm = try PercentEncoding.decodeForm(encodedForm)
    #expect(decodedForm == original, "round-trip failed for .form")
}

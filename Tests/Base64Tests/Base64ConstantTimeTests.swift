import Testing
import Bytes
@testable import Base64

@Test func constantTimeDecodesValidInput() throws {
    let result = try Base64.decode("Zm9vYmFy", mode: .constantTime)
    #expect(Array(result) == Array("foobar".utf8))
}

@Test func constantTimeAcceptsBothAlphabets() throws {
    let standard = try Base64.decode("+/+/", mode: .constantTime)
    let urlSafe  = try Base64.decode("-_-_", mode: .constantTime)
    #expect(Array(standard) == [0xFB, 0xFF, 0xBF])
    #expect(Array(urlSafe)  == [0xFB, 0xFF, 0xBF])
}

@Test func constantTimeRejectsWhitespace() {
    // .lenient would accept "Zm9v\nYmFy"; .constantTime rejects.
    #expect(throws: Base64Error.constantTimeRejected) {
        _ = try Base64.decode("Zm9v\nYmFy", mode: .constantTime)
    }
}

@Test func constantTimeRejectsInvalidCharacterWithoutOffset() {
    #expect(throws: Base64Error.constantTimeRejected) {
        _ = try Base64.decode("Z!9v", mode: .constantTime)
    }
}

@Test func constantTimeHandlesPadded() throws {
    let result = try Base64.decode("Zg==", mode: .constantTime)
    #expect(Array(result) == [0x66])
}

@Test func constantTimeSmokeTimingInvariance() {
    // Smoke test: a fully valid input and one with a single invalid byte
    // at the midpoint should not be wildly different in wall-clock time.
    // This is NOT a real timing-attack defense — see Layer 25 for that.
    let validBytes = [UInt8](repeating: 0x41, count: 1000)  // all 'A'
    let valid = String(decoding: validBytes, as: UTF8.self)
    var invalidBytes = validBytes
    invalidBytes[500] = 0x21  // '!' invalid in middle
    let invalid = String(decoding: invalidBytes, as: UTF8.self)

    let start1 = ContinuousClock().now
    _ = try? Base64.decode(valid, mode: .constantTime)
    let dt1 = ContinuousClock().now - start1

    let start2 = ContinuousClock().now
    _ = try? Base64.decode(invalid, mode: .constantTime)
    let dt2 = ContinuousClock().now - start2

    // Allow a wide ratio because this is a smoke test, not a real
    // statistical analysis. We just want to catch a 100x divergence
    // that would indicate the decoder bailed out early on the invalid
    // input.
    let nanos1 = dt1.components.attoseconds / 1_000_000_000
    let nanos2 = dt2.components.attoseconds / 1_000_000_000
    let ratio = max(nanos1, nanos2) / max(min(nanos1, nanos2), 1)
    #expect(ratio < 10, "Timing ratio \(ratio) suggests early-exit on invalid input")
}

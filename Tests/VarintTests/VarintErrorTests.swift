import Testing
import Bytes
@testable import Varint

@Test func varintErrorEquality() {
    #expect(VarintError.truncated == VarintError.truncated)
    #expect(VarintError.overflow == VarintError.overflow)
    #expect(VarintError.truncated != VarintError.overflow)
}

@Test func boundsConstants() {
    #expect(Varint.maxBytes32 == 5)
    #expect(Varint.maxBytes64 == 10)
}

@Test func decodeEmptyInputThrowsTruncated() {
    var r = BytesReader(Bytes())
    #expect(throws: VarintError.truncated) {
        _ = try Varint.decodeUInt64(from: &r)
    }
}

@Test func decodeContinuationBitOnLastByteThrowsTruncated() {
    var r = BytesReader(Bytes([0x80]))
    #expect(throws: VarintError.truncated) {
        _ = try Varint.decodeUInt64(from: &r)
    }
}

@Test func decodeUInt64TooManyBytesThrowsOverflow() {
    let raw: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]
    var r = BytesReader(Bytes(raw))
    #expect(throws: VarintError.overflow) {
        _ = try Varint.decodeUInt64(from: &r)
    }
}

@Test func decodeUInt64FinalBytePayloadTooLargeThrowsOverflow() {
    let raw: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x02]
    var r = BytesReader(Bytes(raw))
    #expect(throws: VarintError.overflow) {
        _ = try Varint.decodeUInt64(from: &r)
    }
}

@Test func decodeUInt32TooManyBytesThrowsOverflow() {
    let raw: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]
    var r = BytesReader(Bytes(raw))
    #expect(throws: VarintError.overflow) {
        _ = try Varint.decodeUInt32(from: &r)
    }
}

@Test func decodeUInt32FinalBytePayloadTooLargeThrowsOverflow() {
    let raw: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0x10]
    var r = BytesReader(Bytes(raw))
    #expect(throws: VarintError.overflow) {
        _ = try Varint.decodeUInt32(from: &r)
    }
}

@Test func decodeNonCanonicalEncodingIsAccepted() throws {
    var r = BytesReader(Bytes([0x80, 0x00]))
    #expect(try Varint.decodeUInt64(from: &r) == 0)
}

@Test func decodeTruncatedAdvancesCursorToFailurePoint() {
    var r = BytesReader(Bytes([0x80]))
    #expect(throws: VarintError.truncated) {
        _ = try Varint.decodeUInt64(from: &r)
    }
    #expect(r.consumed == 1)
}

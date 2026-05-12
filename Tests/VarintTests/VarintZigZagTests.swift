import Testing
import Bytes
@testable import Varint

@Test func zigzagKnownVectors() {
    // ZigZag mapping: 0→0, -1→1, 1→2, -2→3, 2→4
    #expect(Array(Varint.encoded(Int64(0))) == [0x00])
    #expect(Array(Varint.encoded(Int64(-1))) == [0x01])
    #expect(Array(Varint.encoded(Int64(1))) == [0x02])
    #expect(Array(Varint.encoded(Int64(-2))) == [0x03])
    #expect(Array(Varint.encoded(Int64(2))) == [0x04])
}

@Test func zigzagInt32KnownVectors() {
    #expect(Array(Varint.encoded(Int32(0))) == [0x00])
    #expect(Array(Varint.encoded(Int32(-1))) == [0x01])
    #expect(Array(Varint.encoded(Int32(1))) == [0x02])
}

@Test func roundTripInt64Boundaries() throws {
    let values: [Int64] = [0, -1, 1, -2, 2, Int64.min, Int64.max, -1000, 1000, Int64.min + 1, Int64.max - 1]
    for v in values {
        var buf = BytesMut()
        Varint.encode(v, into: &buf)
        var r = BytesReader(buf.freeze())
        let decoded = try Varint.decodeInt64(from: &r)
        #expect(decoded == v, "Int64 round-trip failed for \(v)")
    }
}

@Test func roundTripInt32Boundaries() throws {
    let values: [Int32] = [0, -1, 1, -2, 2, Int32.min, Int32.max, -1000, 1000, Int32.min + 1, Int32.max - 1]
    for v in values {
        var buf = BytesMut()
        Varint.encode(v, into: &buf)
        var r = BytesReader(buf.freeze())
        let decoded = try Varint.decodeInt32(from: &r)
        #expect(decoded == v, "Int32 round-trip failed for \(v)")
    }
}

@Test func zigzagInt64MinRoundTrips() throws {
    let v = Int64.min
    var buf = BytesMut()
    Varint.encode(v, into: &buf)
    var r = BytesReader(buf.freeze())
    #expect(try Varint.decodeInt64(from: &r) == Int64.min)
}

@Test func zigzagInt32MinRoundTrips() throws {
    let v = Int32.min
    var buf = BytesMut()
    Varint.encode(v, into: &buf)
    var r = BytesReader(buf.freeze())
    #expect(try Varint.decodeInt32(from: &r) == Int32.min)
}

@Test func zigzagNegativeAndPositiveTwinSameLength() {
    #expect(Array(Varint.encoded(Int64(-100))).count == Array(Varint.encoded(Int64(99))).count)
    #expect(Array(Varint.encoded(Int64(-1_000_000))).count == Array(Varint.encoded(Int64(999_999))).count)
}

@Test func decodedInt64FromBytesReturnsValueAndConsumed() throws {
    let bytes = Varint.encoded(Int64(-1000))
    let (v, consumed) = try Varint.decodeInt64(from: bytes)
    #expect(v == -1000)
    #expect(consumed == bytes.count)
}

@Test func decodedInt32FromBytesReturnsValueAndConsumed() throws {
    let bytes = Varint.encoded(Int32(-1000))
    let (v, consumed) = try Varint.decodeInt32(from: bytes)
    #expect(v == -1000)
    #expect(consumed == bytes.count)
}

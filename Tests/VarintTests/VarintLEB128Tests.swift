import Testing
import Bytes
@testable import Varint

@Test func encodeUInt64Zero() {
    var buf = BytesMut()
    let n = Varint.encode(UInt64(0), into: &buf)
    #expect(n == 1)
    #expect(Array(buf.freeze()) == [0x00])
}

@Test func encodeUInt64SmallValues() {
    var buf = BytesMut()
    Varint.encode(UInt64(1), into: &buf)
    Varint.encode(UInt64(127), into: &buf)
    Varint.encode(UInt64(128), into: &buf)
    Varint.encode(UInt64(150), into: &buf)
    #expect(Array(buf.freeze()) == [0x01, 0x7F, 0x80, 0x01, 0x96, 0x01])
}

@Test func encodeUInt64TwoByteBoundary() {
    var buf = BytesMut()
    Varint.encode(UInt64(16383), into: &buf)
    Varint.encode(UInt64(16384), into: &buf)
    #expect(Array(buf.freeze()) == [0xFF, 0x7F, 0x80, 0x80, 0x01])
}

@Test func encodeUInt32Max() {
    var buf = BytesMut()
    let n = Varint.encode(UInt32.max, into: &buf)
    #expect(n == 5)
    #expect(Array(buf.freeze()) == [0xFF, 0xFF, 0xFF, 0xFF, 0x0F])
}

@Test func encodeUInt64Max() {
    var buf = BytesMut()
    let n = Varint.encode(UInt64.max, into: &buf)
    #expect(n == 10)
    #expect(Array(buf.freeze()) == [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
}

@Test func encodeUInt32MatchesUInt64ForSmallValues() {
    var bufA = BytesMut()
    var bufB = BytesMut()
    Varint.encode(UInt32(150), into: &bufA)
    Varint.encode(UInt64(150), into: &bufB)
    #expect(Array(bufA.freeze()) == Array(bufB.freeze()))
}

@Test func encodeAppendsToExistingBuffer() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    Varint.encode(UInt64(150), into: &buf)
    #expect(Array(buf.freeze()) == [0xAA, 0x96, 0x01])
}

@Test func decodeUInt64KnownVectors() throws {
    var r = BytesReader(Bytes([0x00, 0x01, 0x7F, 0x80, 0x01, 0x96, 0x01]))
    #expect(try Varint.decodeUInt64(from: &r) == 0)
    #expect(try Varint.decodeUInt64(from: &r) == 1)
    #expect(try Varint.decodeUInt64(from: &r) == 127)
    #expect(try Varint.decodeUInt64(from: &r) == 128)
    #expect(try Varint.decodeUInt64(from: &r) == 150)
    #expect(r.isExhausted == true)
}

@Test func decodeUInt32KnownVectors() throws {
    var r = BytesReader(Bytes([0xFF, 0xFF, 0xFF, 0xFF, 0x0F]))
    #expect(try Varint.decodeUInt32(from: &r) == UInt32.max)
    #expect(r.isExhausted == true)
}

@Test func decodeUInt64MaxValue() throws {
    var r = BytesReader(Bytes([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]))
    #expect(try Varint.decodeUInt64(from: &r) == UInt64.max)
    #expect(r.isExhausted == true)
}

@Test func roundTripUInt64Powers() throws {
    let values: [UInt64] = [
        0, 1, 127, 128, 16383, 16384,
        UInt64(1) << 32, UInt64(UInt32.max), UInt64.max - 1, UInt64.max,
    ]
    for v in values {
        var buf = BytesMut()
        Varint.encode(v, into: &buf)
        var r = BytesReader(buf.freeze())
        let decoded = try Varint.decodeUInt64(from: &r)
        #expect(decoded == v, "round-trip failed for \(v)")
    }
}

@Test func roundTripUInt32Boundaries() throws {
    let values: [UInt32] = [0, 1, 127, 128, 16383, 16384, UInt32.max - 1, UInt32.max]
    for v in values {
        var buf = BytesMut()
        Varint.encode(v, into: &buf)
        var r = BytesReader(buf.freeze())
        let decoded = try Varint.decodeUInt32(from: &r)
        #expect(decoded == v, "round-trip failed for \(v)")
    }
}

@Test func encodeReturnCountMatchesDecodeConsumed() throws {
    var buf = BytesMut()
    let written = Varint.encode(UInt64(0x1_2345_6789), into: &buf)
    var r = BytesReader(buf.freeze())
    _ = try Varint.decodeUInt64(from: &r)
    #expect(r.consumed == written)
}

@Test func encodedUInt64ReturnsBytes() {
    #expect(Array(Varint.encoded(UInt64(0))) == [0x00])
    #expect(Array(Varint.encoded(UInt64(150))) == [0x96, 0x01])
    #expect(Array(Varint.encoded(UInt64.max)).count == 10)
}

@Test func encodedUInt32ReturnsBytes() {
    #expect(Array(Varint.encoded(UInt32(150))) == [0x96, 0x01])
    #expect(Array(Varint.encoded(UInt32.max)).count == 5)
}

@Test func decodeUInt64FromBytesReturnsValueAndConsumed() throws {
    // Encode three values back-to-back, then decode the first one.
    var buf = BytesMut()
    Varint.encode(UInt64(150), into: &buf)
    Varint.encode(UInt64(99), into: &buf)
    Varint.encode(UInt64(7), into: &buf)
    let frozen = buf.freeze()
    let (v, consumed) = try Varint.decodeUInt64(from: frozen)
    #expect(v == 150)
    #expect(consumed == 2)
}

@Test func decodeUInt32FromBytesReturnsValueAndConsumed() throws {
    let bytes = Varint.encoded(UInt32(16384))  // 3 bytes
    let (v, consumed) = try Varint.decodeUInt32(from: bytes)
    #expect(v == 16384)
    #expect(consumed == 3)
}

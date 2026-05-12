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

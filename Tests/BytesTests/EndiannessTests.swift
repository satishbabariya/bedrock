import Testing
@testable import Bytes

@Test func endiannessCasesAreSendable() {
    let cases: [Endianness] = [.big, .little, .host]
    #expect(cases.count == 3)
}

@Test func bytesErrorEquality() {
    #expect(BytesError.outOfBounds(offset: 0, length: 4, bufferCount: 2)
            == BytesError.outOfBounds(offset: 0, length: 4, bufferCount: 2))
    #expect(BytesError.shortRead(needed: 4, available: 2)
            == BytesError.shortRead(needed: 4, available: 2))
    #expect(BytesError.invalidLength(-1) == BytesError.invalidLength(-1))
    #expect(BytesError.shortRead(needed: 4, available: 2)
            != BytesError.shortRead(needed: 4, available: 3))
}

@Test func roundTripUInt16AllEndianness() {
    for endianness in [Endianness.big, .little, .host] {
        let value: UInt16 = 0xDEAD
        var m = BytesMut()
        m.putUInt16(value, endianness: endianness)
        var r = BytesReader(m.freeze())
        #expect(r.readUInt16(endianness: endianness) == value)
    }
}

@Test func roundTripUInt32AllEndianness() {
    for endianness in [Endianness.big, .little, .host] {
        let value: UInt32 = 0xDEADBEEF
        var m = BytesMut()
        m.putUInt32(value, endianness: endianness)
        var r = BytesReader(m.freeze())
        #expect(r.readUInt32(endianness: endianness) == value)
    }
}

@Test func roundTripUInt64AllEndianness() {
    for endianness in [Endianness.big, .little, .host] {
        let value: UInt64 = 0x0123_4567_89AB_CDEF
        var m = BytesMut()
        m.putUInt64(value, endianness: endianness)
        var r = BytesReader(m.freeze())
        #expect(r.readUInt64(endianness: endianness) == value)
    }
}

@Test func roundTripSignedIntegers() {
    for endianness in [Endianness.big, .little, .host] {
        var m = BytesMut()
        m.putInt8(-1)
        m.putInt16(-2, endianness: endianness)
        m.putInt32(-3, endianness: endianness)
        m.putInt64(-4, endianness: endianness)
        var r = BytesReader(m.freeze())
        #expect(r.readInt8() == -1)
        #expect(r.readInt16(endianness: endianness) == -2)
        #expect(r.readInt32(endianness: endianness) == -3)
        #expect(r.readInt64(endianness: endianness) == -4)
    }
}

@Test func bigEndianBytePatternIsExact() {
    var m = BytesMut()
    m.putUInt32(0x11223344, endianness: .big)
    #expect(Array(m.freeze()) == [0x11, 0x22, 0x33, 0x44])
}

@Test func littleEndianBytePatternIsExact() {
    var m = BytesMut()
    m.putUInt32(0x11223344, endianness: .little)
    #expect(Array(m.freeze()) == [0x44, 0x33, 0x22, 0x11])
}

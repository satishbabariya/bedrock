import Testing
@testable import Bytes

@Test func loadFixedBigEndianUInt32() {
    let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
    bytes.withUnsafeBytes { buf in
        let v: UInt32 = loadFixed(UInt32.self,
                                  from: buf.baseAddress!,
                                  offset: 0,
                                  endianness: .big)
        #expect(v == 0xDEADBEEF)
    }
}

@Test func loadFixedLittleEndianUInt32() {
    let bytes: [UInt8] = [0xEF, 0xBE, 0xAD, 0xDE]
    bytes.withUnsafeBytes { buf in
        let v: UInt32 = loadFixed(UInt32.self,
                                  from: buf.baseAddress!,
                                  offset: 0,
                                  endianness: .little)
        #expect(v == 0xDEADBEEF)
    }
}

@Test func storeFixedBigEndianUInt32() {
    var bytes = [UInt8](repeating: 0, count: 4)
    bytes.withUnsafeMutableBytes { buf in
        storeFixed(UInt32(0xDEADBEEF),
                   to: buf.baseAddress!,
                   offset: 0,
                   endianness: .big)
    }
    #expect(bytes == [0xDE, 0xAD, 0xBE, 0xEF])
}

@Test func storeFixedLittleEndianUInt32() {
    var bytes = [UInt8](repeating: 0, count: 4)
    bytes.withUnsafeMutableBytes { buf in
        storeFixed(UInt32(0xDEADBEEF),
                   to: buf.baseAddress!,
                   offset: 0,
                   endianness: .little)
    }
    #expect(bytes == [0xEF, 0xBE, 0xAD, 0xDE])
}

@Test func loadFixedRespectsOffset() {
    let bytes: [UInt8] = [0x00, 0x00, 0xDE, 0xAD]
    bytes.withUnsafeBytes { buf in
        let v: UInt16 = loadFixed(UInt16.self,
                                  from: buf.baseAddress!,
                                  offset: 2,
                                  endianness: .big)
        #expect(v == 0xDEAD)
    }
}

@Test func loadFixedHandlesUnalignedOffsets() {
    let bytes: [UInt8] = [0xAA, 0xDE, 0xAD, 0xBE, 0xEF, 0xBB]
    bytes.withUnsafeBytes { buf in
        let v: UInt32 = loadFixed(UInt32.self,
                                  from: buf.baseAddress!,
                                  offset: 1,
                                  endianness: .big)
        #expect(v == 0xDEADBEEF)
    }
}

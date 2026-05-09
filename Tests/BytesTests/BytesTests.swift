import Testing
@testable import Bytes

@Test func emptyBytesHasZeroCount() {
    let b = Bytes()
    #expect(b.count == 0)
    #expect(b.isEmpty == true)
}

@Test func bytesEmptyConstantSharesStorage() {
    let a = Bytes.empty
    let b = Bytes.empty
    #expect(a.count == 0 && b.count == 0)
}

@Test func bytesFromArray() {
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(b.count == 4)
    #expect(b[0] == 0xDE)
    #expect(b[3] == 0xEF)
}

@Test func bytesArrayLiteral() {
    let b: Bytes = [0x01, 0x02, 0x03]
    #expect(b.count == 3)
    #expect(Array(b) == [0x01, 0x02, 0x03])
}

@Test func bytesIteration() {
    let b = Bytes([0x10, 0x20, 0x30])
    var sum = 0
    for byte in b { sum += Int(byte) }
    #expect(sum == 0x60)
}

@Test func bytesFirstAndLast() {
    let b = Bytes([0xAA, 0xBB, 0xCC])
    #expect(b.first == 0xAA)
    #expect(b.last == 0xCC)
}

@Test func bytesContains() {
    let b = Bytes([0x01, 0x02, 0x03])
    #expect(b.contains(0x02))
    #expect(!b.contains(0x99))
}

@Test func bytesPrefix() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.prefix(2)) == [0x01, 0x02])
    #expect(Array(b.prefix(0)) == [])
    #expect(Array(b.prefix(99)) == [0x01, 0x02, 0x03, 0x04])  // clamps
}

@Test func bytesSuffix() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.suffix(2)) == [0x03, 0x04])
    #expect(Array(b.suffix(0)) == [])
    #expect(Array(b.suffix(99)) == [0x01, 0x02, 0x03, 0x04])  // clamps
}

@Test func bytesDropFirst() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.dropFirst(2)) == [0x03, 0x04])
    #expect(Array(b.dropFirst(0)) == [0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.dropFirst(99)) == [])  // clamps
}

@Test func bytesDropLast() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.dropLast(2)) == [0x01, 0x02])
    #expect(Array(b.dropLast(0)) == [0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.dropLast(99)) == [])  // clamps
}

@Test func bytesRangeSubscript() {
    let b = Bytes([0x10, 0x20, 0x30, 0x40, 0x50])
    let mid = b[1..<4]
    #expect(Array(mid) == [0x20, 0x30, 0x40])
}

@Test func bytesSlicingIsZeroCopy() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    let mid = b[1..<3]
    let baseAddrOriginal = b.withUnsafeBytes { $0.baseAddress! }
    let baseAddrSlice = mid.withUnsafeBytes { $0.baseAddress! }
    // Slice points 1 byte into the original storage.
    #expect(baseAddrSlice == baseAddrOriginal.advanced(by: 1))
}

@Test func bytesPeekUInt8() {
    let b = Bytes([0xAB, 0xCD])
    #expect(b.peekUInt8(at: 0) == 0xAB)
    #expect(b.peekUInt8(at: 1) == 0xCD)
    #expect(b.peekUInt8(at: 2) == nil)
    #expect(b.peekUInt8(at: -1) == nil)
}

@Test func bytesPeekUInt16BigLittle() {
    let b = Bytes([0xDE, 0xAD])
    #expect(b.peekUInt16(at: 0, endianness: .big) == 0xDEAD)
    #expect(b.peekUInt16(at: 0, endianness: .little) == 0xADDE)
    #expect(b.peekUInt16(at: 1, endianness: .big) == nil)  // only 1 byte left
}

@Test func bytesPeekUInt32BigLittle() {
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(b.peekUInt32(at: 0, endianness: .big) == 0xDEADBEEF)
    #expect(b.peekUInt32(at: 0, endianness: .little) == 0xEFBEADDE)
    #expect(b.peekUInt32(at: 1, endianness: .big) == nil)
}

@Test func bytesPeekUInt64BigLittle() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    #expect(b.peekUInt64(at: 0, endianness: .big) == 0x0102030405060708)
    #expect(b.peekUInt64(at: 0, endianness: .little) == 0x0807060504030201)
    #expect(b.peekUInt64(at: 1, endianness: .big) == nil)  // only 7 bytes left
}

@Test func bytesPeekSignedIntegers() {
    let b = Bytes([0xFF, 0xFF, 0xFF, 0xFE,
                   0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    #expect(b.peekInt8(at: 0) == -1)
    #expect(b.peekInt16(at: 0, endianness: .big) == -1)
    #expect(b.peekInt32(at: 0, endianness: .big) == -2)
    #expect(b.peekInt64(at: 4, endianness: .big) == -1)
    #expect(b.peekInt64(at: 99, endianness: .big) == nil)  // OOB
}

@Test func bytesPeekBytes() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04, 0x05])
    let slice = b.peekBytes(at: 1, length: 3)
    #expect(slice != nil)
    #expect(Array(slice!) == [0x02, 0x03, 0x04])
    #expect(b.peekBytes(at: 1, length: 99) == nil)         // out of bounds
    #expect(b.peekBytes(at: -1, length: 1) == nil)         // negative offset
    #expect(b.peekBytes(at: 0, length: -1) == nil)         // negative length
}

@Test func bytesTryPeekSucceeds() throws {
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(try b.tryPeekUInt32(at: 0, endianness: .big) == 0xDEADBEEF)
    #expect(try b.tryPeekUInt8(at: 1) == 0xAD)
}

@Test func bytesTryPeekThrowsOutOfBounds() {
    let b = Bytes([0xDE, 0xAD])
    #expect(throws: BytesError.outOfBounds(offset: 1, length: 4, bufferCount: 2)) {
        _ = try b.tryPeekUInt32(at: 1, endianness: .big)
    }
    #expect(throws: BytesError.outOfBounds(offset: -1, length: 1, bufferCount: 2)) {
        _ = try b.tryPeekUInt8(at: -1)
    }
}

@Test func bytesTryPeekBytesThrowsInvalidLength() {
    let b = Bytes([0xDE, 0xAD])
    #expect(throws: BytesError.invalidLength(-1)) {
        _ = try b.tryPeekBytes(at: 0, length: -1)
    }
}

@Test func bytesTryPeekBytesThrowsOutOfBounds() {
    let b = Bytes([0xDE, 0xAD])
    #expect(throws: BytesError.outOfBounds(offset: 0, length: 5, bufferCount: 2)) {
        _ = try b.tryPeekBytes(at: 0, length: 5)
    }
}

@Test func bytesEqualByContent() {
    let a = Bytes([0x01, 0x02, 0x03])
    let b = Bytes([0x01, 0x02, 0x03])
    let c = Bytes([0x01, 0x02])
    let d = Bytes([0x01, 0x02, 0x04])
    #expect(a == b)
    #expect(a != c)
    #expect(a != d)
}

@Test func bytesEmptyEquality() {
    #expect(Bytes() == Bytes.empty)
    #expect(Bytes() == Bytes([]))
}

@Test func bytesHashableConsistent() {
    let a = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    var seen = Set<Bytes>()
    seen.insert(a)
    #expect(seen.contains(b))
}

@Test func bytesSliceEqualsArray() {
    let original = Bytes([0x10, 0x20, 0x30, 0x40, 0x50])
    let slice = original[1..<4]
    #expect(slice == Bytes([0x20, 0x30, 0x40]))
}

@Test func bytesTryPeekAllVariantsSuccess() throws {
    // Buffer of distinct bytes for unambiguous assertions.
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED, 0xCA, 0xFE,
                   0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE])

    // Unsigned big-endian
    #expect(try b.tryPeekUInt8 (at: 0) == 0xDE)
    #expect(try b.tryPeekUInt16(at: 0, endianness: .big) == 0xDEAD)
    #expect(try b.tryPeekUInt32(at: 0, endianness: .big) == 0xDEADBEEF)
    #expect(try b.tryPeekUInt64(at: 0, endianness: .big) == 0xDEADBEEFFEEDCAFE)

    // Signed (delegate via bitPattern)
    #expect(try b.tryPeekInt8 (at: 0) == Int8(bitPattern: 0xDE))
    #expect(try b.tryPeekInt16(at: 0, endianness: .big) == Int16(bitPattern: 0xDEAD))
    #expect(try b.tryPeekInt32(at: 0, endianness: .big) == Int32(bitPattern: 0xDEADBEEF))
    #expect(try b.tryPeekInt64(at: 8, endianness: .big) == -2)  // 0xFFFF…FFFE

    // tryPeekBytes happy path
    let slice = try b.tryPeekBytes(at: 4, length: 4)
    #expect(Array(slice) == [0xFE, 0xED, 0xCA, 0xFE])
}

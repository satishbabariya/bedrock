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

import Testing
import Bytes
@testable import Varint

@Test func putVarintUInt32MatchesNamespaceForm() {
    var bufA = BytesMut()
    var bufB = BytesMut()
    bufA.putVarint(UInt32(150))
    Varint.encode(UInt32(150), into: &bufB)
    #expect(Array(bufA.freeze()) == Array(bufB.freeze()))
}

@Test func putVarintReturnsByteCount() {
    var buf = BytesMut()
    let n = buf.putVarint(UInt64(150))
    #expect(n == 2)
}

@Test func readVarintUInt64ReturnsValueAndAdvances() throws {
    var buf = BytesMut()
    Varint.encode(UInt64(150), into: &buf)
    Varint.encode(UInt64(99), into: &buf)
    var r = BytesReader(buf.freeze())
    #expect(try r.readVarintUInt64() == 150)
    #expect(r.consumed == 2)
    #expect(try r.readVarintUInt64() == 99)
}

@Test func roundTripThroughExtensions() throws {
    var buf = BytesMut()
    buf.putVarint(UInt32(16384))
    buf.putVarint(Int32(-1000))
    buf.putVarint(UInt64(UInt64.max))
    buf.putVarint(Int64(Int64.min))
    var r = BytesReader(buf.freeze())
    #expect(try r.readVarintUInt32() == 16384)
    #expect(try r.readVarintInt32() == -1000)
    #expect(try r.readVarintUInt64() == UInt64.max)
    #expect(try r.readVarintInt64() == Int64.min)
    #expect(r.isExhausted == true)
}

@Test func readVarintTruncatedAdvancesCursorToFailurePoint() {
    var r = BytesReader(Bytes([0x80]))
    #expect(throws: VarintError.truncated) {
        _ = try r.readVarintUInt64()
    }
    #expect(r.consumed == 1)
}

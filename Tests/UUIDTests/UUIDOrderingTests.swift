import Testing
import Bytes
@testable import UUID

@Test func nilSortsBeforeAnything() throws {
    let u = try UUID(bytes: [UInt8](repeating: 1, count: 16))
    #expect(UUID.nil < u)
    #expect(!(u < UUID.nil))
}

@Test func maxSortsAfterAnything() throws {
    let u = try UUID(bytes: [UInt8](repeating: 1, count: 16))
    #expect(u < UUID.max)
    #expect(!(UUID.max < u))
}

@Test func equalUUIDsAreNotLess() {
    #expect(!(UUID.nil < UUID.nil))
    #expect(!(UUID.max < UUID.max))
}

@Test func lexicographicOrder() throws {
    var a = [UInt8](repeating: 0, count: 16); a[0] = 0x01
    var b = [UInt8](repeating: 0, count: 16); b[0] = 0x02
    let ua = try UUID(bytes: a)
    let ub = try UUID(bytes: b)
    #expect(ua < ub)
}

@Test func lateBytesBreakTiesAfterEarlyEqual() throws {
    var a = [UInt8](repeating: 0xAA, count: 16)
    var b = [UInt8](repeating: 0xAA, count: 16)
    a[15] = 0x01
    b[15] = 0x02
    let ua = try UUID(bytes: a)
    let ub = try UUID(bytes: b)
    #expect(ua < ub)
}

@Test func equalHashesAreEqual() {
    #expect(UUID.nil.hashValue == UUID.nil.hashValue)
}

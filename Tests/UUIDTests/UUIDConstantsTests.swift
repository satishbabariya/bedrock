import Testing
import Bytes
@testable import UUID

@Test func nilUUIDAllZero() {
    let n = UUID.nil
    #expect(Array(n.bytes) == [UInt8](repeating: 0, count: 16))
}

@Test func maxUUIDAllOnes() {
    let m = UUID.max
    #expect(Array(m.bytes) == [UInt8](repeating: 0xFF, count: 16))
}

@Test func uuidEquatable() {
    #expect(UUID.nil == UUID.nil)
    #expect(UUID.nil != UUID.max)
}

@Test func uuidHashable() {
    var seen: Set<UUID> = []
    seen.insert(.nil)
    seen.insert(.max)
    #expect(seen.contains(.nil))
    #expect(seen.contains(.max))
    #expect(seen.count == 2)
}

@Test func initFromBytesSucceeds() throws {
    let raw: [UInt8] = (0..<16).map { UInt8($0) }
    let u = try UUID(bytes: Bytes(raw))
    #expect(Array(u.bytes) == raw)
}

@Test func initFromSequenceSucceeds() throws {
    let raw: [UInt8] = (0..<16).map { UInt8($0) }
    let u = try UUID(bytes: raw)
    #expect(Array(u.bytes) == raw)
}

@Test func initFromBytesWrongLengthThrows() {
    let short = Bytes([UInt8](repeating: 0, count: 15))
    #expect(throws: UUIDError.invalidByteCount(15)) {
        _ = try UUID(bytes: short)
    }
    let long = Bytes([UInt8](repeating: 0, count: 17))
    #expect(throws: UUIDError.invalidByteCount(17)) {
        _ = try UUID(bytes: long)
    }
}

@Test func initFromSequenceWrongLengthThrows() {
    let short: [UInt8] = [0, 1, 2]
    #expect(throws: UUIDError.invalidByteCount(3)) {
        _ = try UUID(bytes: short)
    }
}

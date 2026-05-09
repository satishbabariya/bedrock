import Testing
@testable import Bytes

@Test func emptySingletonHasZeroCapacity() {
    let s = BytesStorage.empty
    #expect(s.capacity == 0)
}

@Test func emptySingletonIsShared() {
    #expect(BytesStorage.empty === BytesStorage.empty)
}

@Test func newStorageHasRequestedCapacity() {
    let s = BytesStorage(capacity: 128)
    #expect(s.capacity == 128)
}

@Test func storageDeallocatesOnLastReference() {
    // Indirect: allocate, drop, allocate again — addresses should be reusable.
    // This isn't deterministic but exercises deinit. ASan run will catch leaks.
    for _ in 0..<1000 {
        _ = BytesStorage(capacity: 1024)
    }
    // If we reach here without crash and ASan reports clean, dealloc works.
    #expect(true)
}

@Test func storageBytesAreReadWritable() {
    let s = BytesStorage(capacity: 8)
    s.pointer.storeBytes(of: UInt32(0xDEADBEEF), as: UInt32.self)
    let v = s.pointer.load(as: UInt32.self)
    #expect(v == 0xDEADBEEF)
}

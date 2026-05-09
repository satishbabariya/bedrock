import Testing
@testable import Bytes

@Test func freezeReturnsContentsAndResetsBuilder() {
    var m = BytesMut()
    m.putBytes([0xDE, 0xAD] as [UInt8])
    let frozen = m.freeze()
    #expect(Array(frozen) == [0xDE, 0xAD])
    #expect(m.count == 0)
    #expect(m.isEmpty == true)
}

@Test func freezeAllowsBuilderReuse() {
    var m = BytesMut()
    m.putUInt8(0xAA)
    let first = m.freeze()
    m.putUInt8(0xBB)
    let second = m.freeze()
    #expect(Array(first) == [0xAA])
    #expect(Array(second) == [0xBB])
}

@Test func snapshotPreservedAcrossMutation() {
    var m = BytesMut()
    m.putBytes([0x01, 0x02] as [UInt8])
    let snap = m.snapshot()
    m.putBytes([0x03, 0x04] as [UInt8])  // triggers CoW
    #expect(Array(snap) == [0x01, 0x02])
    #expect(Array(m.snapshot()) == [0x01, 0x02, 0x03, 0x04])
}

@Test func snapshotForcesCoWOnNextMutation() {
    var m = BytesMut(capacity: 64)
    m.putBytes([0xAA, 0xBB] as [UInt8])
    let snap = m.snapshot()  // hold the snapshot alive
    let snapAddr = snap.withUnsafeBytes { $0.baseAddress! }
    m.putUInt8(0xCC)  // CoW expected because snap is still alive here
    let postAddr = m.snapshot().withUnsafeBytes { $0.baseAddress! }
    #expect(snapAddr != postAddr)
    // Use snap after the CoW point to keep ARC from optimizing it away.
    #expect(snap.count == 2)
}

@Test func freezeIntoBytesIsZeroCopyOnImmediateAccess() {
    var m = BytesMut(capacity: 64)
    m.putBytes([0x01, 0x02, 0x03] as [UInt8])
    let storageAddr = m.snapshot().withUnsafeBytes { $0.baseAddress! }
    let frozen = m.freeze()
    let frozenAddr = frozen.withUnsafeBytes { $0.baseAddress! }
    #expect(storageAddr == frozenAddr)
}

@Test func cowStress() {
    var m = BytesMut()
    var snapshots: [Bytes] = []
    for i in 0..<10_000 {
        m.putUInt8(UInt8(i & 0xFF))
        if i % 100 == 0 {
            snapshots.append(m.snapshot())
        }
    }
    #expect(m.count == 10_000)
    for (idx, snap) in snapshots.enumerated() {
        let expectedCount = idx * 100 + 1
        #expect(snap.count == expectedCount)
    }
}

@Test func clearReleasesSharedStorage() {
    var m = BytesMut(capacity: 64)
    m.putBytes([0x01, 0x02, 0x03] as [UInt8])
    let snap = m.snapshot()  // makes storage shared
    m.clear()
    // After clear() on shared storage, the builder no longer holds the
    // original allocation; capacity drops to 0 (empty singleton).
    #expect(m.capacity == 0)
    // Snapshot is unaffected.
    #expect(Array(snap) == [0x01, 0x02, 0x03])
    // A fresh put after clear allocates new storage independent of snapshot.
    m.putUInt8(0xAA)
    #expect(Array(m.snapshot()) == [0xAA])
    #expect(Array(snap) == [0x01, 0x02, 0x03])
}

@Test func clearOnUniqueStorageRetainsCapacity() {
    var m = BytesMut(capacity: 64)
    m.putBytes([0x01, 0x02] as [UInt8])
    let cap = m.capacity
    m.clear()  // unique → retain
    #expect(m.capacity == cap)
    #expect(m.count == 0)
}

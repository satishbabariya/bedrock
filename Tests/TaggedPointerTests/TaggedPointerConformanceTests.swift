import Testing
import TaggedPointer

@Suite
struct TaggedPointerConformanceTests {

    @Test
    func equatableSamePointerSameTag() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let a = TaggedPointer<UInt64>(pointer: p, tag: 3)
        let b = TaggedPointer<UInt64>(pointer: p, tag: 3)
        #expect(a == b)
    }

    @Test
    func equatableSamePointerDifferentTag() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let a = TaggedPointer<UInt64>(pointer: p, tag: 3)
        let b = TaggedPointer<UInt64>(pointer: p, tag: 4)
        #expect(a != b)
    }

    @Test
    func equatableDifferentPointerSameTag() {
        let p1 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p1.deallocate() }
        let p2 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p2.deallocate() }

        let a = TaggedPointer<UInt64>(pointer: p1, tag: 3)
        let b = TaggedPointer<UInt64>(pointer: p2, tag: 3)
        #expect(a != b)
    }

    @Test
    func equatableBothNullDifferentTag() {
        let a = TaggedPointer<UInt64>(pointer: nil, tag: 0)
        let b = TaggedPointer<UInt64>(pointer: nil, tag: 1)
        #expect(a != b)
    }

    @Test
    func hashableEqualValuesHashEqual() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let a = TaggedPointer<UInt64>(pointer: p, tag: 3)
        let b = TaggedPointer<UInt64>(pointer: p, tag: 3)
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }

    @Test
    func hashableUsableInSet() {
        let p1 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p1.deallocate() }
        let p2 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p2.deallocate() }

        var s = Set<TaggedPointer<UInt64>>()
        s.insert(TaggedPointer(pointer: p1, tag: 0))
        s.insert(TaggedPointer(pointer: p1, tag: 0))   // duplicate
        s.insert(TaggedPointer(pointer: p1, tag: 1))
        s.insert(TaggedPointer(pointer: p2, tag: 0))
        s.insert(TaggedPointer(pointer: nil, tag: 0))
        #expect(s.count == 4)
    }

    @Test
    func sendable() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 3)
        Task.detached { @Sendable in
            let _ = tp
        }
    }
}

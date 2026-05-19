import Testing
import TaggedPointer

@Suite
struct TaggedPointerDerivationTests {

    @Test
    func withTagSetsNewTagPointerUnchanged() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 2)
        let derived = tp.withTag(5)
        #expect(derived.pointer == p)
        #expect(derived.tag == 5)
    }

    @Test
    func withTagZeroClearsTag() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 7)
        let cleared = tp.withTag(0)
        #expect(cleared.pointer == p)
        #expect(cleared.tag == 0)
    }

    @Test
    func withPointerSetsNewPointerTagUnchanged() {
        let p1 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p1.deallocate() }
        let p2 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p2.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p1, tag: 4)
        let derived = tp.withPointer(p2)
        #expect(derived.pointer == p2)
        #expect(derived.tag == 4)
    }

    @Test
    func withPointerNilClearsPointerTagUnchanged() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 3)
        let derived = tp.withPointer(nil)
        #expect(derived.pointer == nil)
        #expect(derived.tag == 3)
    }

    @Test
    func chainedDerivation() {
        let p1 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p1.deallocate() }
        let p2 = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p2.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p1, tag: 1)
        let result = tp.withTag(2).withPointer(p2).withTag(5)
        #expect(result.pointer == p2)
        #expect(result.tag == 5)
    }

    @Test
    func derivationDoesNotMutateOriginal() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 3)
        _ = tp.withTag(7)
        #expect(tp.pointer == p)
        #expect(tp.tag == 3)
    }
}

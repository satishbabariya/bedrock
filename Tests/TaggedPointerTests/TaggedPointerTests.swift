import Testing
import TaggedPointer

@Suite
struct TaggedPointerTests {

    @Test
    func nullPointerWithDefaultTagRoundTrips() {
        let tp = TaggedPointer<UInt64>(pointer: nil)
        #expect(tp.pointer == nil)
        #expect(tp.tag == 0)
    }

    @Test
    func nullPointerWithNonZeroTagRoundTrips() {
        // UInt64 alignment 8 -> 3 tag bits, maxTag 7.
        let tp = TaggedPointer<UInt64>(pointer: nil, tag: 5)
        #expect(tp.pointer == nil)
        #expect(tp.tag == 5)
    }

    @Test
    func heapPointerWithTagRoundTrips() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }
        p.pointee = 0xDEAD_BEEF_CAFE_F00D

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 3)
        #expect(tp.pointer == p)
        #expect(tp.tag == 3)
        #expect(tp.pointer?.pointee == 0xDEAD_BEEF_CAFE_F00D)
    }

    @Test
    func heapPointerWithDefaultTagRoundTrips() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }
        let tp = TaggedPointer<UInt64>(pointer: p)
        #expect(tp.pointer == p)
        #expect(tp.tag == 0)
    }
}

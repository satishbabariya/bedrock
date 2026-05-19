import Testing
import TaggedPointer

@Suite
struct TaggedPointerBoundaryTests {

    @Test
    func tagAtMaxRoundTrips() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: TaggedPointer<UInt64>.maxTag)
        #expect(tp.tag == 7)
        #expect(tp.pointer == p)
    }

    @Test
    func tagZeroRoundTripsWithNonNullPointer() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt64>(pointer: p, tag: 0)
        #expect(tp.tag == 0)
        #expect(tp.pointer == p)
    }

    @Test
    func allTagValuesRoundTripForUInt64() {
        let p = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        defer { p.deallocate() }

        for t: UInt in 0 ... 7 {
            let tp = TaggedPointer<UInt64>(pointer: p, tag: t)
            #expect(tp.tag == t)
            #expect(tp.pointer == p)
        }
    }

    @Test
    func uint8PointerWithZeroTagRoundTrips() {
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp = TaggedPointer<UInt8>(pointer: p, tag: 0)
        #expect(tp.pointer == p)
        #expect(tp.tag == 0)
    }

    @Test
    func uint16PointerWithBothTagValuesRoundTrips() {
        let p = UnsafeMutablePointer<UInt16>.allocate(capacity: 1)
        defer { p.deallocate() }

        let tp0 = TaggedPointer<UInt16>(pointer: p, tag: 0)
        #expect(tp0.tag == 0)
        #expect(tp0.pointer == p)

        let tp1 = TaggedPointer<UInt16>(pointer: p, tag: 1)
        #expect(tp1.tag == 1)
        #expect(tp1.pointer == p)
    }
}

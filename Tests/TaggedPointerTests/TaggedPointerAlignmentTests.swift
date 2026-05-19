import Testing
import TaggedPointer

@Suite
struct TaggedPointerAlignmentTests {

    @Test
    func uint8HasZeroTagBits() {
        #expect(TaggedPointer<UInt8>.tagBits == 0)
        #expect(TaggedPointer<UInt8>.tagMask == 0)
        #expect(TaggedPointer<UInt8>.maxTag == 0)
    }

    @Test
    func uint16HasOneTagBit() {
        #expect(TaggedPointer<UInt16>.tagBits == 1)
        #expect(TaggedPointer<UInt16>.tagMask == 1)
        #expect(TaggedPointer<UInt16>.maxTag == 1)
    }

    @Test
    func uint32HasTwoTagBits() {
        #expect(TaggedPointer<UInt32>.tagBits == 2)
        #expect(TaggedPointer<UInt32>.tagMask == 3)
        #expect(TaggedPointer<UInt32>.maxTag == 3)
    }

    @Test
    func uint64HasThreeTagBits() {
        #expect(TaggedPointer<UInt64>.tagBits == 3)
        #expect(TaggedPointer<UInt64>.tagMask == 7)
        #expect(TaggedPointer<UInt64>.maxTag == 7)
    }

    @Test
    func intTagBitsMatchAlignment() {
        let expected = MemoryLayout<Int>.alignment.trailingZeroBitCount
        #expect(TaggedPointer<Int>.tagBits == expected)
    }

    @Test
    func doubleHasThreeTagBits() {
        #expect(TaggedPointer<Double>.tagBits == 3)
    }
}

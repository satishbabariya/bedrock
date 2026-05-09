/// A noncopyable cursor over an immutable `Bytes`. Reads advance the cursor;
/// noncopyable semantics prevent accidental cursor forks across consumers.
public struct BytesReader: ~Copyable {
    @usableFromInline let bytes: Bytes
    @usableFromInline var cursor: Int

    public init(_ bytes: Bytes) {
        self.bytes = bytes
        self.cursor = 0
    }

    public var remaining: Int { bytes.count - cursor }
    public var consumed: Int { cursor }
    public var isExhausted: Bool { cursor >= bytes.count }

    /// Returns the unread tail without advancing.
    public func remainingBytes() -> Bytes {
        bytes[cursor..<bytes.count]
    }
}

extension BytesReader {
    public mutating func readUInt8() -> UInt8? {
        guard let v = bytes.peekUInt8(at: cursor) else { return nil }
        cursor += 1
        return v
    }

    public mutating func readInt8() -> Int8? {
        readUInt8().map(Int8.init(bitPattern:))
    }

    public mutating func readUInt16(endianness: Endianness) -> UInt16? {
        guard let v = bytes.peekUInt16(at: cursor, endianness: endianness)
        else { return nil }
        cursor += 2
        return v
    }

    public mutating func readInt16(endianness: Endianness) -> Int16? {
        readUInt16(endianness: endianness).map(Int16.init(bitPattern:))
    }

    public mutating func readUInt32(endianness: Endianness) -> UInt32? {
        guard let v = bytes.peekUInt32(at: cursor, endianness: endianness)
        else { return nil }
        cursor += 4
        return v
    }

    public mutating func readInt32(endianness: Endianness) -> Int32? {
        readUInt32(endianness: endianness).map(Int32.init(bitPattern:))
    }

    public mutating func readUInt64(endianness: Endianness) -> UInt64? {
        guard let v = bytes.peekUInt64(at: cursor, endianness: endianness)
        else { return nil }
        cursor += 8
        return v
    }

    public mutating func readInt64(endianness: Endianness) -> Int64? {
        readUInt64(endianness: endianness).map(Int64.init(bitPattern:))
    }

    public mutating func readBytes(length: Int) -> Bytes? {
        guard length >= 0,
              let slice = bytes.peekBytes(at: cursor, length: length) else {
            return nil
        }
        cursor += length
        return slice
    }
}

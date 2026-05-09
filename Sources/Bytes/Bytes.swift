/// An immutable, refcounted, zero-copy view over a byte buffer.
public struct Bytes: Sendable {
    @usableFromInline let storage: BytesStorage
    @usableFromInline let offset: Int
    @usableFromInline let length: Int

    @usableFromInline
    init(storage: BytesStorage, offset: Int, length: Int) {
        self.storage = storage
        self.offset = offset
        self.length = length
    }

    /// An empty `Bytes` value sharing a process-wide singleton storage.
    public static let empty = Bytes(storage: .empty, offset: 0, length: 0)

    public init() {
        self = .empty
    }

    public init<S: Sequence>(_ bytes: S) where S.Element == UInt8 {
        let array = Array(bytes)
        if array.isEmpty {
            self = .empty
            return
        }
        let storage = BytesStorage(capacity: array.count)
        array.withUnsafeBufferPointer { src in
            storage.pointer.copyMemory(from: src.baseAddress!,
                                       byteCount: array.count)
        }
        self.init(storage: storage, offset: 0, length: array.count)
    }

    public var count: Int { length }
    public var isEmpty: Bool { length == 0 }
}

extension Bytes: RandomAccessCollection {
    public typealias Element = UInt8
    public typealias Index = Int

    public var startIndex: Int { 0 }
    public var endIndex: Int { length }

    public subscript(position: Int) -> UInt8 {
        precondition(position >= 0 && position < length,
                     "Bytes index out of range")
        return storage.pointer.load(fromByteOffset: offset + position,
                                    as: UInt8.self)
    }
}

extension Bytes: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: UInt8...) {
        self.init(elements)
    }
}

extension Bytes {
    public func prefix(_ n: Int) -> Bytes {
        let take = Swift.max(0, Swift.min(n, length))
        return Bytes(storage: storage, offset: offset, length: take)
    }

    public func suffix(_ n: Int) -> Bytes {
        let take = Swift.max(0, Swift.min(n, length))
        return Bytes(storage: storage,
                     offset: offset + (length - take),
                     length: take)
    }

    public func dropFirst(_ n: Int) -> Bytes {
        let drop = Swift.max(0, Swift.min(n, length))
        return Bytes(storage: storage,
                     offset: offset + drop,
                     length: length - drop)
    }

    public func dropLast(_ n: Int) -> Bytes {
        let drop = Swift.max(0, Swift.min(n, length))
        return Bytes(storage: storage,
                     offset: offset,
                     length: length - drop)
    }

    public subscript(range: Range<Int>) -> Bytes {
        precondition(range.lowerBound >= 0 && range.upperBound <= length,
                     "Bytes range out of bounds")
        return Bytes(storage: storage,
                     offset: offset + range.lowerBound,
                     length: range.count)
    }

    public func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        let start = storage.pointer.advanced(by: offset)
        let buffer = UnsafeRawBufferPointer(start: length == 0 ? nil : start,
                                            count: length)
        return try body(buffer)
    }
}

extension Bytes {
    @inlinable
    public func peekUInt8(at offset: Int) -> UInt8? {
        guard offset >= 0, offset + 1 <= length else { return nil }
        return storage.pointer.load(
            fromByteOffset: self.offset + offset, as: UInt8.self)
    }

    @inlinable
    public func peekInt8(at offset: Int) -> Int8? {
        guard let u = peekUInt8(at: offset) else { return nil }
        return Int8(bitPattern: u)
    }

    @inlinable
    public func peekUInt16(at offset: Int, endianness: Endianness) -> UInt16? {
        guard offset >= 0, offset + 2 <= length else { return nil }
        return loadFixed(UInt16.self, from: storage.pointer,
                         offset: self.offset + offset, endianness: endianness)
    }

    @inlinable
    public func peekInt16(at offset: Int, endianness: Endianness) -> Int16? {
        peekUInt16(at: offset, endianness: endianness).map(Int16.init(bitPattern:))
    }

    @inlinable
    public func peekUInt32(at offset: Int, endianness: Endianness) -> UInt32? {
        guard offset >= 0, offset + 4 <= length else { return nil }
        return loadFixed(UInt32.self, from: storage.pointer,
                         offset: self.offset + offset, endianness: endianness)
    }

    @inlinable
    public func peekInt32(at offset: Int, endianness: Endianness) -> Int32? {
        peekUInt32(at: offset, endianness: endianness).map(Int32.init(bitPattern:))
    }

    @inlinable
    public func peekUInt64(at offset: Int, endianness: Endianness) -> UInt64? {
        guard offset >= 0, offset + 8 <= length else { return nil }
        return loadFixed(UInt64.self, from: storage.pointer,
                         offset: self.offset + offset, endianness: endianness)
    }

    @inlinable
    public func peekInt64(at offset: Int, endianness: Endianness) -> Int64? {
        peekUInt64(at: offset, endianness: endianness).map(Int64.init(bitPattern:))
    }

    @inlinable
    public func peekBytes(at offset: Int, length: Int) -> Bytes? {
        guard offset >= 0, length >= 0, offset + length <= self.length else {
            return nil
        }
        return Bytes(storage: storage,
                     offset: self.offset + offset,
                     length: length)
    }
}

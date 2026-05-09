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

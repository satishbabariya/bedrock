/// A mutable byte builder with copy-on-write semantics. Freezes into `Bytes`.
public struct BytesMut {
    @usableFromInline var storage: BytesStorage
    @usableFromInline var _count: Int

    public init() {
        self.storage = .empty
        self._count = 0
    }

    public init(capacity: Int) {
        precondition(capacity >= 0, "BytesMut capacity must be non-negative")
        self.storage = capacity == 0 ? .empty : BytesStorage(capacity: capacity)
        self._count = 0
    }

    public init<S: Sequence>(_ bytes: S) where S.Element == UInt8 {
        let array = Array(bytes)
        self.storage = array.isEmpty ? .empty : BytesStorage(capacity: array.count)
        self._count = array.count
        if !array.isEmpty {
            array.withUnsafeBufferPointer { src in
                storage.pointer.copyMemory(from: src.baseAddress!,
                                           byteCount: array.count)
            }
        }
    }

    public var count: Int { _count }
    public var capacity: Int { storage.capacity }
    public var isEmpty: Bool { _count == 0 }

    public mutating func reserveCapacity(_ n: Int) {
        precondition(n >= 0, "reserveCapacity must be non-negative")
        ensureCapacity(forAdditional: Swift.max(0, n - _count))
    }

    public mutating func clear() {
        _count = 0
        // Storage is retained; growth is lazy on next put.
    }

    /// Ensures the storage can hold `_count + additional` bytes total, performing
    /// CoW if shared. Internal helper used by all mutating ops.
    @usableFromInline
    mutating func ensureCapacity(forAdditional additional: Int) {
        let required = _count + additional
        let unique = isKnownUniquelyReferenced(&storage)
        if required <= storage.capacity && unique {
            return
        }
        let newCapacity: Int
        if required <= storage.capacity {
            newCapacity = storage.capacity
        } else {
            let doubled = storage.capacity &* 2
            newCapacity = Swift.max(required, Swift.max(doubled, 64))
        }
        let newStorage = BytesStorage(capacity: newCapacity)
        if _count > 0 {
            newStorage.pointer.copyMemory(
                from: UnsafeRawPointer(storage.pointer),
                byteCount: _count)
        }
        storage = newStorage
    }
}

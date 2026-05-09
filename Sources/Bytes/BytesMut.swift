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

extension BytesMut {
    public mutating func putUInt8(_ v: UInt8) {
        ensureCapacity(forAdditional: 1)
        storage.pointer.storeBytes(of: v, toByteOffset: _count, as: UInt8.self)
        _count += 1
    }

    public mutating func putInt8(_ v: Int8) {
        putUInt8(UInt8(bitPattern: v))
    }

    public mutating func putUInt16(_ v: UInt16, endianness: Endianness) {
        ensureCapacity(forAdditional: 2)
        storeFixed(v, to: storage.pointer, offset: _count, endianness: endianness)
        _count += 2
    }

    public mutating func putInt16(_ v: Int16, endianness: Endianness) {
        putUInt16(UInt16(bitPattern: v), endianness: endianness)
    }

    public mutating func putUInt32(_ v: UInt32, endianness: Endianness) {
        ensureCapacity(forAdditional: 4)
        storeFixed(v, to: storage.pointer, offset: _count, endianness: endianness)
        _count += 4
    }

    public mutating func putInt32(_ v: Int32, endianness: Endianness) {
        putUInt32(UInt32(bitPattern: v), endianness: endianness)
    }

    public mutating func putUInt64(_ v: UInt64, endianness: Endianness) {
        ensureCapacity(forAdditional: 8)
        storeFixed(v, to: storage.pointer, offset: _count, endianness: endianness)
        _count += 8
    }

    public mutating func putInt64(_ v: Int64, endianness: Endianness) {
        putUInt64(UInt64(bitPattern: v), endianness: endianness)
    }

    public mutating func putBytes<S: Sequence>(_ bytes: S) where S.Element == UInt8 {
        let array = Array(bytes)
        guard !array.isEmpty else { return }
        ensureCapacity(forAdditional: array.count)
        array.withUnsafeBufferPointer { src in
            storage.pointer.advanced(by: _count).copyMemory(
                from: src.baseAddress!, byteCount: array.count)
        }
        _count += array.count
    }

    public mutating func putBytes(_ other: Bytes) {
        guard !other.isEmpty else { return }
        ensureCapacity(forAdditional: other.count)
        other.withUnsafeBytes { src in
            storage.pointer.advanced(by: _count).copyMemory(
                from: src.baseAddress!, byteCount: src.count)
        }
        _count += other.count
    }

    /// Non-consuming snapshot. Returns a `Bytes` referencing the current
    /// storage; subsequent mutations CoW into a new storage.
    public func snapshot() -> Bytes {
        Bytes(storage: storage, offset: 0, length: _count)
    }

    public mutating func withUnsafeMutableBytes<R>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> R
    ) rethrows -> R {
        ensureCapacity(forAdditional: 0)  // CoW if shared
        let buffer = UnsafeMutableRawBufferPointer(
            start: _count == 0 ? nil : storage.pointer, count: _count)
        return try body(buffer)
    }
}

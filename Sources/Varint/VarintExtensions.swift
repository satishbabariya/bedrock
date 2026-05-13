import Bytes

extension BytesMut {
    @discardableResult
    public mutating func putVarint(_ v: UInt32) -> Int { Varint.encode(v, into: &self) }

    @discardableResult
    public mutating func putVarint(_ v: UInt64) -> Int { Varint.encode(v, into: &self) }

    @discardableResult
    public mutating func putVarint(_ v: Int32) -> Int { Varint.encode(v, into: &self) }

    @discardableResult
    public mutating func putVarint(_ v: Int64) -> Int { Varint.encode(v, into: &self) }
}

extension BytesReader {
    public mutating func readVarintUInt32() throws -> UInt32 {
        try Varint.decodeUInt32(from: &self)
    }

    public mutating func readVarintUInt64() throws -> UInt64 {
        try Varint.decodeUInt64(from: &self)
    }

    public mutating func readVarintInt32() throws -> Int32 {
        try Varint.decodeInt32(from: &self)
    }

    public mutating func readVarintInt64() throws -> Int64 {
        try Varint.decodeInt64(from: &self)
    }
}

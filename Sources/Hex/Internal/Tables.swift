/// Lowercase hex alphabet ("0"..."9", "a"..."f"). Indexed by 0...15.
@usableFromInline
internal let hexLowerAlphabet: [UInt8] = Array("0123456789abcdef".utf8)

/// Uppercase hex alphabet ("0"..."9", "A"..."F"). Indexed by 0...15.
@usableFromInline
internal let hexUpperAlphabet: [UInt8] = Array("0123456789ABCDEF".utf8)

/// 256-entry decode table mapping ASCII byte → nibble value (0...15)
/// or 0xFF for non-hex bytes.
@usableFromInline
internal let hexDecodeTable: [UInt8] = (0..<256).map { i in
    switch UInt8(i) {
    case 0x30...0x39: return UInt8(i - 0x30)        // '0'-'9'
    case 0x41...0x46: return UInt8(i - 0x41 + 10)   // 'A'-'F'
    case 0x61...0x66: return UInt8(i - 0x61 + 10)   // 'a'-'f'
    default:          return 0xFF
    }
}

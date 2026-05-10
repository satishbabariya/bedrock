/// Lowercase hex alphabet ("0"..."9", "a"..."f"). Indexed by 0...15.
@usableFromInline
internal let hexLowerAlphabet: [UInt8] = Array("0123456789abcdef".utf8)

/// Uppercase hex alphabet ("0"..."9", "A"..."F"). Indexed by 0...15.
@usableFromInline
internal let hexUpperAlphabet: [UInt8] = Array("0123456789ABCDEF".utf8)

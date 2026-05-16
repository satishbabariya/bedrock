/// Per-set encoding rules: safe-byte bitmap (256 entries) + space-as-plus flag.
internal struct SetTable {
    let safe: [Bool]
    let spaceAsPlus: Bool
}

@inline(__always)
private func isUnreserved(_ b: UInt8) -> Bool {
    switch b {
    case 0x41...0x5A, 0x61...0x7A, 0x30...0x39: return true   // A-Z a-z 0-9
    case 0x2D, 0x2E, 0x5F, 0x7E:                return true   // - . _ ~
    default:                                    return false
    }
}

@inline(__always)
private func isSubDelim(_ b: UInt8) -> Bool {
    switch b {
    case 0x21, 0x24, 0x26, 0x27, 0x28, 0x29,                 // ! $ & ' ( )
         0x2A, 0x2B, 0x2C, 0x3B, 0x3D:                       // * + , ; =
        return true
    default: return false
    }
}

internal let unreservedTable = SetTable(
    safe: (0..<256).map { isUnreserved(UInt8($0)) },
    spaceAsPlus: false
)

internal let pathSegmentTable = SetTable(
    safe: (0..<256).map { b in
        let u = UInt8(b)
        return isUnreserved(u) || isSubDelim(u) || u == 0x3A || u == 0x40
        //                                          ':'        '@'
    },
    spaceAsPlus: false
)

internal let queryTable = SetTable(
    safe: (0..<256).map { b in
        let u = UInt8(b)
        // sub-delims minus '&' (0x26) and '=' (0x3D) so they remain
        // meaningful inside a value.
        let subDelimForQuery: Bool = {
            switch u {
            case 0x21, 0x24, 0x27, 0x28, 0x29,
                 0x2A, 0x2B, 0x2C, 0x3B:
                return true
            default: return false
            }
        }()
        return isUnreserved(u) || subDelimForQuery
            || u == 0x3A || u == 0x40 || u == 0x2F || u == 0x3F
        //     ':'           '@'         '/'         '?'
    },
    spaceAsPlus: false
)

internal let fragmentTable = SetTable(
    safe: (0..<256).map { b in
        let u = UInt8(b)
        return isUnreserved(u) || isSubDelim(u)
            || u == 0x3A || u == 0x40 || u == 0x2F || u == 0x3F
    },
    spaceAsPlus: false
)

internal let userinfoTable = SetTable(
    safe: (0..<256).map { b in
        let u = UInt8(b)
        return isUnreserved(u) || isSubDelim(u) || u == 0x3A
    },
    spaceAsPlus: false
)

internal let componentTable = SetTable(
    safe: (0..<256).map { isUnreserved(UInt8($0)) },
    spaceAsPlus: false
)

internal let formTable = SetTable(
    safe: (0..<256).map { isUnreserved(UInt8($0)) },
    spaceAsPlus: true
)

/// Uppercase hex alphabet (RFC 3986 §2.1 SHOULD).
internal let hexUpper: [UInt8] = Array("0123456789ABCDEF".utf8)

@inline(__always)
internal func setTable(for set: PercentEncoding.Set) -> SetTable {
    switch set {
    case .unreserved:  return unreservedTable
    case .pathSegment: return pathSegmentTable
    case .query:       return queryTable
    case .fragment:    return fragmentTable
    case .userinfo:    return userinfoTable
    case .component:   return componentTable
    case .form:        return formTable
    }
}

/// Local nibble decoder — duplicated from Hex by design (peer Layer 1 module).
@inline(__always)
internal func decodeNibble(_ b: UInt8) -> UInt8 {
    switch b {
    case 0x30...0x39: return b - 0x30           // '0'-'9'
    case 0x41...0x46: return b - 0x41 + 10      // 'A'-'F'
    case 0x61...0x66: return b - 0x61 + 10      // 'a'-'f'
    default:          return 0xFF
    }
}

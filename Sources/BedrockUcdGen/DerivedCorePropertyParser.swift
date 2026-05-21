public struct DerivedCorePropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let propertyName: String

    public init(first: UInt32, last: UInt32, propertyName: String) {
        self.first = first
        self.last = last
        self.propertyName = propertyName
    }
}

public enum DerivedCorePropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyName(lineNumber: Int)
}

public enum DerivedCorePropertyParser {

    public static func parse(_ text: String) throws -> [DerivedCorePropertyEntry] {
        var entries: [DerivedCorePropertyEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.dcpTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw DerivedCorePropertyParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).dcpTrimmed()
            let nameField  = String(fields[1]).dcpTrimmed()

            if nameField.isEmpty {
                throw DerivedCorePropertyParseError.emptyPropertyName(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.dcpRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).dcpTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).dcpTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr, radix: 16) else {
                    throw DerivedCorePropertyParseError.invalidRange(lineNumber: lineNumber,
                                                                      raw: rangeField)
                }
                first = f
                last = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw DerivedCorePropertyParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                          raw: rangeField)
                }
                first = cp
                last = cp
            }

            entries.append(DerivedCorePropertyEntry(first: first,
                                                     last: last,
                                                     propertyName: nameField))
        }
        return entries
    }
}

public extension Array where Element == DerivedCorePropertyEntry {
    /// XID_Start: valid identifier-start codepoints per UAX #31.
    func expandXIDStart() -> [UInt8] {
        expand(matching: "XID_Start")
    }

    /// XID_Continue: valid identifier-continuation codepoints per UAX #31.
    func expandXIDContinue() -> [UInt8] {
        expand(matching: "XID_Continue")
    }

    /// Generic helper consumed by the property-specific entry points.
    private func expand(matching propertyName: String) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self where entry.propertyName == propertyName {
            for cp in entry.first...entry.last {
                out[Int(cp)] = 1
            }
        }
        return out
    }
}

private extension String {
    func dcpTrimmed() -> String {
        var startIdx = self.startIndex
        while startIdx < self.endIndex,
              [" ", "\t", "\r"].contains(self[startIdx]) {
            startIdx = self.index(after: startIdx)
        }
        var endIdx = self.endIndex
        while endIdx > startIdx {
            let prev = self.index(before: endIdx)
            if ![" ", "\t", "\r"].contains(self[prev]) { break }
            endIdx = prev
        }
        return String(self[startIdx..<endIdx])
    }

    /// Returns the range of the first occurrence of `needle` in `self`,
    /// using only stdlib Character comparisons (no Foundation).
    func dcpRange(of needle: String) -> Range<String.Index>? {
        guard !needle.isEmpty else { return startIndex..<startIndex }
        var i = startIndex
        let needleFirst = needle[needle.startIndex]
        while i < endIndex {
            if self[i] == needleFirst {
                var si = i
                var ni = needle.startIndex
                while ni < needle.endIndex, si < endIndex, self[si] == needle[ni] {
                    si = index(after: si)
                    ni = needle.index(after: ni)
                }
                if ni == needle.endIndex {
                    return i..<si
                }
            }
            i = index(after: i)
        }
        return nil
    }
}

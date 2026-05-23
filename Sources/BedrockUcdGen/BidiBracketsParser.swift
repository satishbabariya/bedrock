public struct BidiBracketEntry: Equatable, Sendable {
    public let codepoint: UInt32
    public let pairedCodepoint: UInt32
    public let type: BracketType

    public enum BracketType: Character, Sendable {
        case open  = "o"
        case close = "c"
    }

    public init(codepoint: UInt32, pairedCodepoint: UInt32, type: BracketType) {
        self.codepoint       = codepoint
        self.pairedCodepoint = pairedCodepoint
        self.type            = type
    }
}

public enum BidiBracketsParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidType(lineNumber: Int, raw: String)
}

public enum BidiBracketsParser {

    public static func parse(_ text: String) throws -> [BidiBracketEntry] {
        var entries: [BidiBracketEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.bbTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            guard fields.count >= 3 else {
                throw BidiBracketsParseError.truncatedLine(lineNumber: lineNumber)
            }

            let cpField     = String(fields[0]).bbTrimmed()
            let pairedField = String(fields[1]).bbTrimmed()
            let typeField   = String(fields[2]).bbTrimmed()

            guard let cp = UInt32(cpField, radix: 16) else {
                throw BidiBracketsParseError.invalidCodepoint(lineNumber: lineNumber,
                                                              raw: cpField)
            }
            guard let paired = UInt32(pairedField, radix: 16) else {
                throw BidiBracketsParseError.invalidCodepoint(lineNumber: lineNumber,
                                                              raw: pairedField)
            }
            guard typeField.count == 1,
                  let typeChar = typeField.first,
                  let bracketType = BidiBracketEntry.BracketType(rawValue: typeChar) else {
                throw BidiBracketsParseError.invalidType(lineNumber: lineNumber,
                                                         raw: typeField)
            }

            entries.append(BidiBracketEntry(codepoint: cp,
                                            pairedCodepoint: paired,
                                            type: bracketType))
        }
        return entries
    }
}

private extension String {
    func bbTrimmed() -> String {
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
}

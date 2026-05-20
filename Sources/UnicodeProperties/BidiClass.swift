extension UnicodeProperties {

    /// Unicode bidirectional class (UnicodeData.txt field 4, UAX #9).
    public enum BidiClass: UInt8, Sendable, Hashable, CaseIterable {
        // Strong
        case leftToRight                  = 0
        case rightToLeft                  = 1
        case arabicLetter                 = 2
        // Weak
        case europeanNumber               = 3
        case europeanSeparator            = 4
        case europeanTerminator           = 5
        case arabicNumber                 = 6
        case commonSeparator              = 7
        case nonspacingMark               = 8
        case boundaryNeutral              = 9
        // Neutral
        case paragraphSeparator           = 10
        case segmentSeparator             = 11
        case whiteSpace                   = 12
        case otherNeutral                 = 13
        // Explicit formatting
        case leftToRightEmbedding         = 14
        case leftToRightOverride          = 15
        case rightToLeftEmbedding         = 16
        case rightToLeftOverride          = 17
        case popDirectionalFormat         = 18
        case leftToRightIsolate           = 19
        case rightToLeftIsolate           = 20
        case firstStrongIsolate           = 21
        case popDirectionalIsolate        = 22
    }
}

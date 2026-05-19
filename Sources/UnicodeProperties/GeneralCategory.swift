extension UnicodeProperties {

    /// Unicode general category (UnicodeData.txt field 3, UAX #44 table 12).
    public enum GeneralCategory: UInt8, Sendable, Hashable, CaseIterable {
        case uppercaseLetter        = 0   // Lu
        case lowercaseLetter        = 1   // Ll
        case titlecaseLetter        = 2   // Lt
        case modifierLetter         = 3   // Lm
        case otherLetter            = 4   // Lo
        case nonspacingMark         = 5   // Mn
        case spacingMark            = 6   // Mc
        case enclosingMark          = 7   // Me
        case decimalNumber          = 8   // Nd
        case letterNumber           = 9   // Nl
        case otherNumber            = 10  // No
        case connectorPunctuation   = 11  // Pc
        case dashPunctuation        = 12  // Pd
        case openPunctuation        = 13  // Ps
        case closePunctuation       = 14  // Pe
        case initialPunctuation     = 15  // Pi
        case finalPunctuation       = 16  // Pf
        case otherPunctuation       = 17  // Po
        case mathSymbol             = 18  // Sm
        case currencySymbol         = 19  // Sc
        case modifierSymbol         = 20  // Sk
        case otherSymbol            = 21  // So
        case spaceSeparator         = 22  // Zs
        case lineSeparator          = 23  // Zl
        case paragraphSeparator     = 24  // Zp
        case control                = 25  // Cc
        case format                 = 26  // Cf
        case surrogate              = 27  // Cs
        case privateUse             = 28  // Co
        case unassigned             = 29  // Cn
    }
}

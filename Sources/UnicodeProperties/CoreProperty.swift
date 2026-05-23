// Boolean DerivedCoreProperty classification entry points live in
// UnicodeProperties.swift to keep the namespace surface co-located with
// other property accessors. This file exists to match the file-per-property
// layout established by BidiClass.swift, CanonicalCombiningClass.swift,
// SimpleCaseMapping.swift, CaseFolding.swift, Identifier.swift, and
// FullCaseFolding.swift.
//
// Properties housed here (5 non-identifier DCP booleans):
//   isMath, isAlphabetic, isCased, isLowercase, isUppercase
//
// The two legacy identifier properties (isIDStart, isIDContinue) fit
// alongside isXIDStart / isXIDContinue conceptually; see Identifier.swift.

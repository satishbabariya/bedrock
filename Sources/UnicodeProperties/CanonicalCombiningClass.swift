// CanonicalCombiningClass is exposed as UInt8 (not a strongly-typed enum)
// because canonical-ordering algorithms consume the value numerically.
//
// Public entry point lives in UnicodeProperties.swift to keep the namespace
// surface co-located with other property accessors. This file exists to
// match the file-per-property layout established in the design spec.

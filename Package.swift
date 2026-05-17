// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bedrock",
    products: [
        .library(name: "Bytes", targets: ["Bytes"]),
        .library(name: "Hex", targets: ["Hex"]),
        .library(name: "Base64", targets: ["Base64"]),
        .library(name: "UUID", targets: ["UUID"]),
        .library(name: "Varint", targets: ["Varint"]),
        .library(name: "PercentEncoding", targets: ["PercentEncoding"]),
        .library(name: "BitSet", targets: ["BitSet"]),
        .library(name: "COBS", targets: ["COBS"]),
    ],
    targets: [
        .target(name: "Bytes", path: "Sources/Bytes"),
        .testTarget(name: "BytesTests", dependencies: ["Bytes"], path: "Tests/BytesTests"),

        .target(name: "Hex", dependencies: ["Bytes"], path: "Sources/Hex"),
        .testTarget(name: "HexTests", dependencies: ["Hex", "Bytes"], path: "Tests/HexTests"),

        .target(name: "Base64", dependencies: ["Bytes"], path: "Sources/Base64"),
        .testTarget(name: "Base64Tests", dependencies: ["Base64", "Bytes"], path: "Tests/Base64Tests"),

        .target(name: "UUID", dependencies: ["Bytes"], path: "Sources/UUID"),
        .testTarget(name: "UUIDTests", dependencies: ["UUID", "Bytes"], path: "Tests/UUIDTests"),

        .target(name: "Varint", dependencies: ["Bytes"], path: "Sources/Varint"),
        .testTarget(name: "VarintTests", dependencies: ["Varint", "Bytes"], path: "Tests/VarintTests"),

        .target(name: "PercentEncoding", dependencies: ["Bytes"], path: "Sources/PercentEncoding"),
        .testTarget(name: "PercentEncodingTests", dependencies: ["PercentEncoding", "Bytes"], path: "Tests/PercentEncodingTests"),

        .target(name: "BitSet", dependencies: ["Bytes"], path: "Sources/BitSet"),
        .testTarget(name: "BitSetTests", dependencies: ["BitSet", "Bytes"], path: "Tests/BitSetTests"),

        .target(name: "COBS", dependencies: ["Bytes"], path: "Sources/COBS"),
        .testTarget(name: "COBSTests", dependencies: ["COBS", "Bytes"], path: "Tests/COBSTests"),
    ]
)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SharedNostrCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "SharedNostrCore",
            targets: ["SharedNostrCore"]
        )
    ],
    dependencies: [
        // Use vendored local copy to avoid resolver issues
        .package(
            path: "Deps/secp256k1.swift"
        )
    ],
    targets: [
        .target(
            name: "SharedNostrCore",
            dependencies: [
                .product(name: "secp256k1", package: "secp256k1.swift")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SharedNostrCoreTests",
            dependencies: ["SharedNostrCore"],
            path: "Tests"
        )
    ]
)


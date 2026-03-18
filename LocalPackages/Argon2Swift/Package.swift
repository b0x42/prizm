// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Argon2Swift",
    platforms: [.macOS(.v10_10), .tvOS(.v9), .iOS(.v9), .watchOS(.v2)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Argon2Swift",
            targets: ["Argon2Swift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Argon2",
            dependencies: [],
            path: "Sources/Argon2",
            exclude: [
                "kats",
                "vs2015",
                "src/blake2/blamka-round-opt.h",
                "src/run.c",
                "src/test.c",
                "src/opt.c",
                "src/bench.c",
                "src/genkat.c",
                "src/genkat.h"
            ]),
        .target(
            name: "Argon2Swift",
            dependencies: ["Argon2"],
            path: "Sources/Swift"),
        .testTarget(
            name: "Argon2SwiftTests",
            dependencies: ["Argon2Swift"],
            path: "Tests"),
    ]
)

// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DangerSwiftFormat",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DangerSwiftFormat",
            targets: ["DangerSwiftFormat"]),
        .library(name: "DangerDeps", type: .dynamic, targets: ["DangerDependencies"]), // dev
    ],
    dependencies: [
        .package(url: "https://github.com/danger/swift.git", from: "3.0.0"),
        // Dev Dependencies
        .package(url: "https://github.com/f-meloni/Rocket", from: "1.0.0"), // dev
        .package(url: "https://github.com/Realm/SwiftLint", from: "0.28.1"), // dev
        .package(url: "https://github.com/f-meloni/danger-swift-coverage", from: "1.0.0"), // dev
        .package(url: "https://github.com/f-meloni/danger-swift-xcodesummary", from: "1.0.0"), // dev
    ],
    targets: [
        .target(name: "DangerDependencies", dependencies: [
            .product(name: "Danger", package: "swift"),
            .product(name: "DangerSwiftCoverage", package: "danger-swift-coverage"),
            .product(name: "DangerXCodeSummary", package: "danger-swift-xcodesummary"),
        ]), // dev
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DangerSwiftFormat"),
        .testTarget(
            name: "DangerSwiftFormatTests",
            dependencies: ["DangerSwiftFormat", .product(name: "DangerFixtures", package: "swift")]),
    ]
)

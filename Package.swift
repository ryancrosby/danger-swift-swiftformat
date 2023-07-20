// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DangerSwiftFormat",
    products: [
        .library(
            name: "DangerSwiftFormat",
            targets: ["DangerSwiftFormat"]
        ),
        .library(name: "DangerDeps", type: .dynamic, targets: ["DangerDependencies"]), // dev
    ],
    dependencies: [
        .package(url: "https://github.com/danger/swift.git", from: "3.0.0"),
        // Dev Dependencies
        .package(url: "https://github.com/f-meloni/Rocket", from: "1.0.0"), // dev
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.35.0"), // dev
        .package(url: "https://github.com/shibapm/Komondor", from: "1.1.4"), // dev
    ],
    targets: [
        .target(name: "DangerDependencies", dependencies: [
            .product(name: "Danger", package: "swift"),
            "DangerSwiftFormat",
        ]), // dev
        .target(
            name: "DangerSwiftFormat",
            dependencies: [.product(name: "Danger", package: "swift")]
        ),
        .testTarget(
            name: "DangerSwiftFormatTests",
            dependencies: ["DangerSwiftFormat", .product(name: "DangerFixtures", package: "swift")]
        ),
    ]
)

#if canImport(PackageConfig)
    import PackageConfig

    let config = PackageConfiguration([
        "komondor": [
            "pre-push": "swift test",
            "pre-commit": [
                "swift run swiftformat .",
                "git add .",
            ],
        ],
        "rocket": [
            "pre_release_checks": [
                "clean_git",
            ],
        ],
    ]).write()
#endif

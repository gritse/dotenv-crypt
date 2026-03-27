// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dotenv-crypt",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "dotenv-crypt",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"])
            ]
        ),
    ]
)

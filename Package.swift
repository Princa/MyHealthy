// swift-tools-version: 5.9
// Test harness for the app's pure-Swift core logic (no SwiftUI / SwiftData).
// Open MyHealthy.xcodeproj to build the app. Run `swift test` here to test the core.
import PackageDescription

let package = Package(
    name: "MyHealthyCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "MyHealthyCore", targets: ["MyHealthyCore"])
    ],
    targets: [
        .target(name: "MyHealthyCore", path: "MyHealthy/Core"),
        .testTarget(name: "MyHealthyCoreTests", dependencies: ["MyHealthyCore"], path: "Tests/MyHealthyCoreTests")
    ]
)

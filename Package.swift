// swift-tools-version: 6.0
import PackageDescription

// Runs protocol regression tests on macOS without a camera or Watch simulator.
// The app itself is built using CRC.xcodeproj.
let package = Package(
    name: "CRCProtocol",
    platforms: [.macOS(.v12), .watchOS(.v9)],
    targets: [
        .target(
            name: "CRCProtocol",
            path: "CRC WatchKit Extension",
            exclude: ["Assets.xcassets", "Preview Content", "BLEClass.swift",
                      "CRCApp.swift", "CRCView.swift", "MainView.swift"],
            sources: ["CanonParams.swift"]
        ),
        .testTarget(name: "CRCProtocolTests", dependencies: ["CRCProtocol"], path: "Tests")
    ]
)

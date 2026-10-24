// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DLPSNotify",
    platforms: [.macOS(.v13)],
    targets: [
        // no AppKit in here, so the tests can poke at it
        .target(name: "DLPSNotifyCore"),

        .executableTarget(
            name: "DLPSNotify",
            dependencies: ["DLPSNotifyCore"]
        ),

        .testTarget(
            name: "DLPSNotifyCoreTests",
            dependencies: ["DLPSNotifyCore"]
        ),
    ]
)

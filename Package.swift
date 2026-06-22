// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DLPSNotify",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure, network/AppKit-free logic — fully unit-testable.
        .target(name: "DLPSNotifyCore"),

        // The menu bar app itself (AppKit + UserNotifications).
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

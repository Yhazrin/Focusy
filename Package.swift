// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Focusy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Focusy", targets: ["Focusy"]),
        .executable(name: "focusy-bridge", targets: ["FocusyBridge"]),
        .executable(name: "FocusyCoreSmokeTests", targets: ["FocusyCoreSmokeTests"]),
        .library(name: "FocusyCore", targets: ["FocusyCore"]),
    ],
    targets: [
        .target(name: "FocusyCore", path: "Sources/FocusyCore"),
        .executableTarget(
            name: "Focusy",
            dependencies: ["FocusyCore"],
            path: "Sources/Focusy"
        ),
        .executableTarget(
            name: "FocusyBridge",
            dependencies: ["FocusyCore"],
            path: "Sources/FocusyBridge"
        ),
        .executableTarget(
            name: "FocusyCoreSmokeTests",
            dependencies: ["FocusyCore"],
            path: "SmokeTests/FocusyCoreSmokeTests"
        ),
    ]
)

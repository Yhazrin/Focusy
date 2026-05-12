// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusCapsule",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FocusCapsule", targets: ["FocusCapsule"]),
        .executable(name: "focuscapsule-bridge", targets: ["FocusCapsuleBridge"]),
        .executable(name: "FocusCapsuleCoreSmokeTests", targets: ["FocusCapsuleCoreSmokeTests"]),
        .library(name: "FocusCapsuleCore", targets: ["FocusCapsuleCore"]),
    ],
    targets: [
        .target(name: "FocusCapsuleCore", path: "Sources/FocusCapsuleCore"),
        .executableTarget(
            name: "FocusCapsule",
            dependencies: ["FocusCapsuleCore"],
            path: "Sources/FocusCapsule"
        ),
        .executableTarget(
            name: "FocusCapsuleBridge",
            dependencies: ["FocusCapsuleCore"],
            path: "Sources/FocusCapsuleBridge"
        ),
        .executableTarget(
            name: "FocusCapsuleCoreSmokeTests",
            dependencies: ["FocusCapsuleCore"],
            path: "SmokeTests/FocusCapsuleCoreSmokeTests"
        ),
    ]
)

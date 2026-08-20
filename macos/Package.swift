// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TeleprompterOverlay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TeleprompterCore", targets: ["TeleprompterCore"]),
        .executable(name: "TeleprompterOverlay", targets: ["TeleprompterOverlay"])
    ],
    targets: [
        .target(name: "TeleprompterCore"),
        .executableTarget(
            name: "TeleprompterOverlay",
            dependencies: ["TeleprompterCore"]
        ),
        .testTarget(
            name: "TeleprompterCoreTests",
            dependencies: ["TeleprompterCore"]
        )
    ]
)

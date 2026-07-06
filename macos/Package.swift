// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpenHaze",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OpenHaze",
            path: "Sources/OpenHaze"
        )
    ]
)

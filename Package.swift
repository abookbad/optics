// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Optics",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Optics",
            path: "Sources/Optics"
        )
    ]
)

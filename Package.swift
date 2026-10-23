// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RetroPet",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "RetroPet", path: "Sources/RetroPet")
    ]
)
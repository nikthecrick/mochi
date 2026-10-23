// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mochi",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Mochi", path: "Sources/RetroPet")
    ]
)
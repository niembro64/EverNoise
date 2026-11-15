// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrownNoiseCore",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "BrownNoiseDSP", targets: ["BrownNoiseDSP"]),
        .library(name: "PlaybackCore", targets: ["PlaybackCore"])
    ],
    targets: [
        .target(name: "BrownNoiseDSP"),
        .target(name: "PlaybackCore"),
        .testTarget(name: "BrownNoiseCoreTests", dependencies: ["BrownNoiseDSP", "PlaybackCore"])
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrownNoiseCore",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "BrownNoiseDSP", targets: ["BrownNoiseDSP"]),
        .library(name: "SpectrumAnalysis", targets: ["SpectrumAnalysis"]),
        .library(name: "PlaybackCore", targets: ["PlaybackCore"])
    ],
    targets: [
        .target(name: "BrownNoiseDSP", path: "shared/dsp"),
        .target(name: "SpectrumAnalysis", dependencies: ["BrownNoiseDSP"], path: "shared/analysis", linkerSettings: [.linkedFramework("Accelerate")]),
        .target(name: "PlaybackCore", path: "apple/Sources/PlaybackCore"),
        .testTarget(name: "BrownNoiseCoreTests", dependencies: ["BrownNoiseDSP", "PlaybackCore", "SpectrumAnalysis"], path: "apple/Tests/BrownNoiseCoreTests")
    ]
)

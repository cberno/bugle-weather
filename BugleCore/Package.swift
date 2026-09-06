// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BugleCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "BugleCore", targets: ["BugleCore"]),
        .executable(name: "bugle-backtest", targets: ["BugleBacktest"])
    ],
    targets: [
        .target(name: "BugleCore"),
        .executableTarget(name: "BugleBacktest", dependencies: ["BugleCore"]),
        .testTarget(name: "BugleCoreTests", dependencies: ["BugleCore"])
    ]
)

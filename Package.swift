// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DicyaninMultiPeer",
    platforms: [
        .iOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DicyaninMultiPeer",
            targets: ["DicyaninMultiPeer"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DicyaninMultiPeer",
            dependencies: []),
        .testTarget(
            name: "DicyaninMultiPeerTests",
            dependencies: ["DicyaninMultiPeer"]),
    ]
) 
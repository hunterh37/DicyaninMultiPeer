// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DicyaninMultiDeviceMP",
    platforms: [
        .iOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DicyaninMultiDeviceMP",
            targets: ["DicyaninMultiDeviceMP"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DicyaninMultiDeviceMP",
            dependencies: []),
        .testTarget(
            name: "DicyaninMultiDeviceMPTests",
            dependencies: ["DicyaninMultiDeviceMP"]),
    ]
) 
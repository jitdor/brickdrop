// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BrickDrop",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BrickDrop", targets: ["BrickDrop"])
    ],
    targets: [
        .executableTarget(name: "BrickDrop"),
        .testTarget(name: "BrickDropTests", dependencies: ["BrickDrop"])
    ]
)

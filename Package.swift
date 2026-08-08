// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MenuBarLiveActivity",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MenuBarLiveActivity",
            targets: ["MenuBarLiveActivity"]
        ),
    ],
    targets: [
        .target(
            name: "MenuBarLiveActivity"
        ),
        .testTarget(
            name: "MenuBarLiveActivityTests",
            dependencies: ["MenuBarLiveActivity"]
        ),
    ]
)

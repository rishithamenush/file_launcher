// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "file_launcher",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "file-launcher", targets: ["file_launcher"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "file_launcher",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            exclude: ["PrivacyInfo.xcprivacy"]
        )
    ]
)

// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MultiClipboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MultiClipboard", targets: ["MultiClipboard"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "MultiClipboard",
            dependencies: ["HotKey"],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-bare-slash-regex"])
            ]
        ),
        .testTarget(
            name: "MultiClipboardTests",
            dependencies: ["MultiClipboard"],
            path: "Tests/MultiClipboardTests"
        )
    ]
) 
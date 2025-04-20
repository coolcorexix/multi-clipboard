// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MultiClipboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MultiClipboard",
            targets: ["MultiClipboard"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "MultiClipboard",
            dependencies: ["HotKey"],
            resources: [
                .copy("Resources/Info.plist")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-bare-slash-regex"])
            ]
        ),
        .testTarget(
            name: "MultiClipboardTests",
            dependencies: ["MultiClipboard"]
        )
    ]
) 
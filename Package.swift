// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NativeMDEditor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NativeMDEditor", targets: ["NativeMDEditor"]) 
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.3.0")
    ],
    targets: [
        .executableTarget(
            name: "NativeMDEditor",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/NativeMDEditor"
        )
    ]
)
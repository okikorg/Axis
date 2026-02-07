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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NativeMDEditor",
            dependencies: [],
            path: "Sources/NativeMDEditor"
        )
    ]
)
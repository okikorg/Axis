// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Axis",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Axis", targets: ["Axis"]) 
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Axis",
            dependencies: [],
            path: "Sources/Axis",
            resources: [
                .copy("Resources/Fonts")
            ]
        )
    ]
)
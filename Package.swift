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
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Axis",
            dependencies: ["SwiftTerm"],
            path: "Sources/Axis",
            resources: [
                .copy("Resources/Fonts")
            ]
        )
    ]
)
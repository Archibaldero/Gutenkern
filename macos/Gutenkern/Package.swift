// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Gutenkern",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "GutenkernCore", targets: ["GutenkernCore"]),
        .executable(name: "Gutenkern", targets: ["Gutenkern"]),
        .executable(name: "GutenkernCoreCheck", targets: ["GutenkernCoreCheck"])
    ],
    targets: [
        .target(
            name: "GutenkernCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Gutenkern",
            dependencies: ["GutenkernCore"]
        ),
        .executableTarget(
            name: "GutenkernCoreCheck",
            dependencies: ["GutenkernCore"]
        )
    ]
)

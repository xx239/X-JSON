// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "XJSON",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "XJSON", targets: ["XJSON"])
    ],
    targets: [
        .executableTarget(
            name: "XJSON",
            path: "JSONLens",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)

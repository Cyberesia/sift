// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sift",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "SiftCore", targets: ["SiftCore"]),
        .library(name: "SiftDesign", targets: ["SiftDesign"]),
        .executable(name: "Sift", targets: ["SiftApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SiftCore",
            dependencies: [
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/SiftCore",
            resources: [
                .copy("Resources/CLIP"),
            ]
        ),
        .target(
            name: "SiftDesign",
            dependencies: ["SiftCore"],
            path: "Sources/SiftDesign"
        ),
        .executableTarget(
            name: "SiftApp",
            dependencies: [
                "SiftCore",
                "SiftDesign",
                .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/SiftApp",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/SiftApp/Info.plist",
                ], .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "SiftIOS",
            dependencies: ["SiftCore", "SiftDesign"],
            path: "Sources/SiftIOS",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "SiftCoreTests",
            dependencies: ["SiftCore"],
            path: "Tests/SiftCoreTests"
        ),
    ]
)

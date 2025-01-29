// swift-tools-version:6.0
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "DefferedTaskKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .macCatalyst(.v13),
        .visionOS(.v1),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "DefferedTaskKit", targets: ["DefferedTaskKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/NikSativa/Threading.git", .upToNextMajor(from: "2.1.0")),
        .package(url: "https://github.com/NikSativa/SpryKit.git", .upToNextMajor(from: "3.0.1"))
    ],
    targets: [
        .target(name: "DefferedTaskKit",
                dependencies: [
                    "Threading"
                ],
                path: "Source",
                resources: [
                    .process("PrivacyInfo.xcprivacy")
                ]),
        .testTarget(name: "DefferedTaskKitTests",
                    dependencies: [
                        "DefferedTaskKit",
                        "Threading",
                        "SpryKit"
                    ],
                    path: "Tests")
    ]
)

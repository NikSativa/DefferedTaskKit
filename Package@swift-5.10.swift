// swift-tools-version:5.10
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "DefferedTaskKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .macCatalyst(.v16),
        .visionOS(.v1),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "DefferedTaskKit", targets: ["DefferedTaskKit"]),
        .library(name: "DefferedTaskKitStatic", type: .static, targets: ["DefferedTaskKit"]),
        .library(name: "DefferedTaskKitDynamic", type: .dynamic, targets: ["DefferedTaskKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/NikSativa/Threading.git", from: "2.2.1"),
        .package(url: "https://github.com/NikSativa/SpryKit.git", from: "3.1.0")
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

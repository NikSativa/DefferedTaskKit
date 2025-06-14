// swift-tools-version:5.9
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
        .library(name: "DefferedTaskKit", targets: ["DefferedTaskKit"]),
        .library(name: "DefferedTaskKitStatic", type: .static, targets: ["DefferedTaskKit"]),
        .library(name: "DefferedTaskKitDynamic", type: .dynamic, targets: ["DefferedTaskKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/NikSativa/Threading.git", from: "2.2.0"),
        .package(url: "https://github.com/NikSativa/SpryKit.git", from: "3.0.4")
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

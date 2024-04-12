// swift-tools-version:5.6
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "DefferedTaskKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "DefferedTaskKit", targets: ["DefferedTaskKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/NikSativa/Threading.git", .upToNextMinor(from: "1.3.3")),
        .package(url: "https://github.com/NikSativa/SpryKit.git", .upToNextMajor(from: "2.2.2"))
    ],
    targets: [
        .target(name: "DefferedTaskKit",
                dependencies: [
                    "Threading"
                ],
                path: "Source",
                resources: [
                    .copy("../PrivacyInfo.xcprivacy")
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

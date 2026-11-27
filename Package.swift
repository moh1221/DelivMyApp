// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DelivMyCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "DelivMyCore", targets: ["DelivMyCore"])],
    targets: [
        .target(name: "DelivMyCore"),
        .testTarget(name: "DelivMyCoreTests", dependencies: ["DelivMyCore"])
    ],
    swiftLanguageModes: [.v6]
)

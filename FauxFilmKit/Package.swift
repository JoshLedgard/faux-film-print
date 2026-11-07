// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FauxFilmKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FauxFilmKit", targets: ["FauxFilmKit"]),
    ],
    targets: [
        .target(name: "FauxFilmKit"),
        .testTarget(name: "FauxFilmKitTests", dependencies: ["FauxFilmKit"]),
    ]
)

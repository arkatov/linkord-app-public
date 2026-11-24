// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Linkord",
    platforms: [.macOS(.v14)],
    targets: [.systemLibrary(name: "CHTML", pkgConfig: "libxml-2.0"),
              .executableTarget(name: "Linkord", dependencies: ["CHTML"])]
)

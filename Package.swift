// swift-tools-version:6.0
import PackageDescription

// WhydunitCore is Foundation-only (builds and tests on Linux/Windows too).
// WhydunitMac holds the macOS collectors and actions, so it only exists on macOS.
var products: [Product] = [.library(name: "WhydunitCore", targets: ["WhydunitCore"])]
var targets: [Target] = [
    .target(name: "WhydunitCore"),
    .testTarget(name: "WhydunitCoreTests", dependencies: ["WhydunitCore"]),
]

#if os(macOS)
products.append(.library(name: "WhydunitMac", targets: ["WhydunitMac"]))
targets += [
    .target(name: "WhydunitMac", dependencies: ["WhydunitCore"]),
    .testTarget(name: "WhydunitMacTests", dependencies: ["WhydunitMac", "WhydunitCore"]),
]
#endif

let package = Package(
    name: "Whydunit",
    platforms: [.macOS(.v15)],
    products: products,
    targets: targets,
    // ponytail: Swift 5 mode keeps strict-concurrency diagnostics as warnings while the code is
    // still unverified on real hardware; move to .v6 once CI is green and warnings are cleaned up.
    swiftLanguageModes: [.v5]
)

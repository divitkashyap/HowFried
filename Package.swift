// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HowFried", platforms: [.macOS(.v14)],
    products: [.executable(name: "HowFried", targets: ["HowFried"]),
               .executable(name: "howfried-hook", targets: ["HowFriedHook"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "HowFriedCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "HowFried", dependencies: ["HowFriedCore"]),
        .executableTarget(name: "HowFriedHook", dependencies: ["HowFriedCore"]),
        .testTarget(name: "HowFriedCoreTests", dependencies: ["HowFriedCore"])
    ])

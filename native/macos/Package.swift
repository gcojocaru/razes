// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Razes", platforms: [.macOS(.v14)],
    products: [.executable(name: "RazesMac", targets: ["RazesMac"])],
    targets: [
        .target(name: "RazesCore", resources: [.process("Resources")]),
        .executableTarget(name: "RazesMac", dependencies: ["RazesCore"], resources: [.copy("Resources")]),
        .testTarget(name: "RazesCoreTests", dependencies: ["RazesCore"], resources: [.copy("Fixtures")]),
        .testTarget(name: "RazesMacTests", dependencies: ["RazesMac"])
    ])

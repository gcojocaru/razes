// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Razes", platforms: [.macOS(.v14)],
  products: [.executable(name: "RazesMac", targets: ["RazesMac"])],
  targets: [
    .target(name: "RazesCore"),
    .executableTarget(
      name: "RazesMac", dependencies: ["RazesCore"], resources: [.copy("Resources")]),
    .testTarget(name: "RazesCoreTests", dependencies: ["RazesCore"]),
    .testTarget(name: "RazesMacTests", dependencies: ["RazesMac"]),
  ])

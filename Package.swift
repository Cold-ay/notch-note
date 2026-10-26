// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "FlowTasks", platforms: [.macOS(.v14)], products: [.executable(name: "FlowTasks", targets: ["FlowTasks"])], targets: [.executableTarget(name: "FlowTasks"), .testTarget(name: "FlowTasksTests", dependencies: ["FlowTasks"])])

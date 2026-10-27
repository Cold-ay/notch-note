// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchAgenda",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NotchAgenda", targets: ["NotchAgenda"])],
    targets: [
        .executableTarget(name: "NotchAgenda"),
        .testTarget(name: "NotchAgendaTests", dependencies: ["NotchAgenda"])
    ]
)

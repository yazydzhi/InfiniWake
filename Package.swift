// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InfiniWake",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "InfiniWake",
            path: "Sources/InfiniWake",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)

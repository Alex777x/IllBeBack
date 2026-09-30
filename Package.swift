// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IllBeBack",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "IllBeBackKit",
            targets: ["IllBeBackKit"]
        ),
        .executable(
            name: "IllBeBack",
            targets: ["IllBeBack"]
        )
    ],
    targets: [
        .target(
            name: "IllBeBackKit",
            path: "Sources/IllBeBackKit",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "IllBeBack",
            dependencies: ["IllBeBackKit"],
            path: "Sources/IllBeBack"
        )
    ]
)

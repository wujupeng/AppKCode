// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppKCode",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "AppKCode", targets: ["AppKCodeApp"])
    ],
    targets: [
        .target(
            name: "AppKCodeShared",
            path: "Sources/AppKCodeShared",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodeInfrastructure",
            dependencies: ["AppKCodeShared"],
            path: "Sources/AppKCodeInfrastructure",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodeDomain",
            dependencies: ["AppKCodeShared", "AppKCodeInfrastructure"],
            path: "Sources/AppKCodeDomain",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodeApplication",
            dependencies: ["AppKCodeShared", "AppKCodeDomain", "AppKCodeInfrastructure"],
            path: "Sources/AppKCodeApplication",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodePresentation",
            dependencies: ["AppKCodeShared", "AppKCodeApplication", "AppKCodeDomain"],
            path: "Sources/AppKCodePresentation",
            swiftSettings: x86_64Settings
        ),
        .executableTarget(
            name: "AppKCodeApp",
            dependencies: ["AppKCodePresentation", "AppKCodeApplication", "AppKCodeDomain", "AppKCodeShared"],
            path: "Sources/AppKCodeApp",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodePluginNative",
            dependencies: ["AppKCodeShared"],
            path: "Sources/AppKCodePluginNative",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodePluginVSCode",
            dependencies: ["AppKCodeShared"],
            path: "Sources/AppKCodePluginVSCode",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodePluginJetBrains",
            dependencies: ["AppKCodeShared"],
            path: "Sources/AppKCodePluginJetBrains",
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeDomainTests",
            dependencies: ["AppKCodeDomain", "AppKCodeShared"],
            path: "Tests/AppKCodeDomainTests",
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeApplicationTests",
            dependencies: ["AppKCodeApplication", "AppKCodeDomain", "AppKCodeShared"],
            path: "Tests/AppKCodeApplicationTests",
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeContractTests",
            dependencies: ["AppKCodeDomain", "AppKCodeApplication", "AppKCodeShared"],
            path: "Tests/AppKCodeContractTests",
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeIntegrationTests",
            dependencies: ["AppKCodeApp", "AppKCodePresentation", "AppKCodeApplication", "AppKCodeDomain", "AppKCodeInfrastructure", "AppKCodeShared"],
            path: "Tests/AppKCodeIntegrationTests",
            swiftSettings: x86_64Settings
        )
    ]
)

let x86_64Settings: [SwiftSetting] = [
    .unsafeFlags(["-target", "x86_64-apple-macos15.0"])
]
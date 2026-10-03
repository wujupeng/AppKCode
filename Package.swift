// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "AppKCode",
    platforms: [
        .macOS(.v13)
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
            name: "AppKCodeExtensionHost",
            dependencies: ["AppKCodeShared"],
            path: "Sources/AppKCodeExtensionHost",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodeDomain",
            dependencies: ["AppKCodeShared", "AppKCodeInfrastructure", "AppKCodeExtensionHost"],
            path: "Sources/AppKCodeDomain",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodeApplication",
            dependencies: ["AppKCodeShared", "AppKCodeDomain", "AppKCodeInfrastructure", "AppKCodeExtensionHost"],
            path: "Sources/AppKCodeApplication",
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodePresentation",
            dependencies: ["AppKCodeShared", "AppKCodeApplication", "AppKCodeDomain", "AppKCodeInfrastructure"],
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
            resources: [
                .copy("resources/extension-host.js"),
                .copy("resources/vscode-shim.js"),
                .copy("resources/workspace-fs-shim.js"),
                .copy("resources/window-commands-shim.js"),
                .copy("resources/base-types-shim.js"),
                .copy("resources/languages-extensions-shim.js")
            ],
            swiftSettings: x86_64Settings
        ),
        .target(
            name: "AppKCodePluginJetBrains",
            dependencies: ["AppKCodeShared"],
            path: "Sources/AppKCodePluginJetBrains",
            resources: [
                .copy("resources/plugin-host.js"),
                .copy("resources/openapi-shim.js"),
                .copy("resources/classloader-isolation.js")
            ],
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeSharedTests",
            dependencies: ["AppKCodeShared"],
            path: "Tests/AppKCodeSharedTests",
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeDomainTests",
            dependencies: ["AppKCodeDomain", "AppKCodeInfrastructure", "AppKCodeShared", "AppKCodeExtensionHost"],
            path: "Tests/AppKCodeDomainTests",
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeInfrastructureTests",
            dependencies: ["AppKCodeInfrastructure", "AppKCodeShared"],
            path: "Tests/AppKCodeInfrastructureTests",
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeExtensionHostTests",
            dependencies: ["AppKCodeExtensionHost", "AppKCodeShared"],
            path: "Tests/AppKCodeExtensionHostTests",
            swiftSettings: x86_64Settings
        ),
        .testTarget(
            name: "AppKCodeApplicationTests",
            dependencies: ["AppKCodeApplication", "AppKCodeDomain", "AppKCodeShared", "AppKCodeExtensionHost", "AppKCodeInfrastructure"],
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
            dependencies: ["AppKCodeApp", "AppKCodePresentation", "AppKCodeApplication", "AppKCodeDomain", "AppKCodeInfrastructure", "AppKCodeShared", "AppKCodeExtensionHost"],
            path: "Tests/AppKCodeIntegrationTests",
            swiftSettings: x86_64Settings
        )
    ]
)

let x86_64Settings: [SwiftSetting] = [
    .unsafeFlags(["-target", "x86_64-apple-macos13.0"])
]
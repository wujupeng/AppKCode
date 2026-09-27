import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeInfrastructure

final class ModelProviderTests: XCTestCase {

    func test_ModelProviderProtocolConformance() {
        let localProvider = LocalModelProvider()
        XCTAssertEqual(localProvider.config.mode, .local)

        let openAIConfig = ModelProviderConfig(
            kind: .openAICompatible,
            mode: .cloud,
            endpoint: URL(string: "https://api.example.com")!,
            apiKey: "key",
            modelName: "test-model"
        )
        let openAIProvider = OpenAICompatProvider(config: openAIConfig)
        XCTAssertEqual(openAIProvider.config.kind, .openAICompatible)
    }

    func test_RegistryRegisterAndResolve() {
        let registry = ModelProviderRegistry()
        let provider = LocalModelProvider()
        registry.register(provider)
        let resolved = registry.resolve(id: provider.id)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.id, provider.id)
    }

    func test_RegistryResolveDefault() {
        let registry = ModelProviderRegistry()
        let provider = LocalModelProvider()
        registry.register(provider)
        let defaultProvider = registry.resolveDefault()
        XCTAssertNotNil(defaultProvider)
        XCTAssertEqual(defaultProvider?.id, provider.id)
    }

    func test_RegistryMultipleProviders() {
        let registry = ModelProviderRegistry()
        let local = LocalModelProvider()
        registry.register(local)
        let cloudConfig = ModelProviderConfig(
            kind: .cloudModel,
            mode: .cloud,
            endpoint: URL(string: "https://api.example.com")!,
            apiKey: "key",
            modelName: "cloud-model"
        )
        let cloud = OpenAICompatProvider(config: cloudConfig)
        registry.register(cloud)
        XCTAssertEqual(registry.allProviders.count, 2)
        XCTAssertNotNil(registry.resolve(id: local.id))
        XCTAssertNotNil(registry.resolve(id: cloud.id))
    }

    func test_RegistrySetDefault() throws {
        let registry = ModelProviderRegistry()
        let local = LocalModelProvider()
        registry.register(local)
        let cloudConfig = ModelProviderConfig(
            kind: .cloudModel,
            mode: .cloud,
            endpoint: URL(string: "https://api.example.com")!,
            apiKey: "key",
            modelName: "cloud-model"
        )
        let cloud = OpenAICompatProvider(config: cloudConfig)
        registry.register(cloud)
        try registry.setDefault(cloud.id)
        XCTAssertEqual(registry.resolveDefault()?.id, cloud.id)
    }

    func test_RegistryIsEmpty() {
        let registry = ModelProviderRegistry()
        XCTAssertTrue(registry.isEmpty)
        let provider = LocalModelProvider()
        registry.register(provider)
        XCTAssertFalse(registry.isEmpty)
    }

    func test_NoVendorSpecificStringsInProviderLayer() {
        let sourcesToCheck = [
            "Sources/AppKCodeDomain/AIChat/ModelProvider.swift",
            "Sources/AppKCodeDomain/AIChat/ModelProviderRegistry.swift",
            "Sources/AppKCodeDomain/AIChat/LocalModelProvider.swift"
        ]
        let vendorStrings = ["huawei", "azure", "anthropic", "claude", "gpt-"]
        for sourcePath in sourcesToCheck {
            guard let content = try? String(contentsOfFile: sourcePath, encoding: .utf8) else { continue }
            let lower = content.lowercased()
            for vendor in vendorStrings {
                XCTAssertFalse(lower.contains(vendor), "Vendor-specific string '\(vendor)' found in \(sourcePath)")
            }
        }
    }
}
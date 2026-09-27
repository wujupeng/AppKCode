import XCTest
@testable import AppKCodeDomain
import AppKCodeShared

final class LocalModeTests: XCTestCase {

    func testH11_DefaultEndpoint() {
        XCTAssertEqual(LocalModeDefaults.endpoint.absoluteString, "http://127.0.0.1:8080")
    }

    func testH11_DefaultMode() {
        XCTAssertEqual(LocalModeDefaults.mode, .local)
    }

    func testH11_ResolveDefaultRegistersLocalProvider() {
        let registry = ModelProviderRegistry()
        let resolver = LocalModeResolver()
        XCTAssertTrue(registry.isEmpty)
        let provider = resolver.resolveDefault(registry: registry)
        XCTAssertEqual(provider.config.mode, .local)
        XCTAssertEqual(provider.config.endpoint, LocalModeDefaults.endpoint)
        XCTAssertFalse(registry.isEmpty)
    }

    func testH11_ResolveDefaultReturnsExistingIfPresent() {
        let registry = ModelProviderRegistry()
        let resolver = LocalModeResolver()
        let first = resolver.resolveDefault(registry: registry)
        let second = resolver.resolveDefault(registry: registry)
        XCTAssertEqual(first.id, second.id)
    }

    func testH11_RegisterCloudRejectsLocalMode() {
        let registry = ModelProviderRegistry()
        let resolver = LocalModeResolver()
        _ = resolver.resolveDefault(registry: registry)
        let localConfig = ModelProviderConfig(
            kind: .cloudModel,
            mode: .local,
            endpoint: URL(string: "https://api.example.com")!,
            apiKey: "key"
        )
        XCTAssertThrowsError(try resolver.registerCloudProvider(localConfig, registry: registry))
    }

    func testH11_RegisterCloudRejectsLocalhost() {
        let registry = ModelProviderRegistry()
        let resolver = LocalModeResolver()
        _ = resolver.resolveDefault(registry: registry)
        let localhostConfig = ModelProviderConfig(
            kind: .cloudModel,
            mode: .cloud,
            endpoint: URL(string: "http://localhost:3000")!,
            apiKey: "key"
        )
        XCTAssertThrowsError(try resolver.registerCloudProvider(localhostConfig, registry: registry))
    }

    func testH11_RegisterCloudRejectsEmptyAPIKey() {
        let registry = ModelProviderRegistry()
        let resolver = LocalModeResolver()
        _ = resolver.resolveDefault(registry: registry)
        let noKeyConfig = ModelProviderConfig(
            kind: .cloudModel,
            mode: .cloud,
            endpoint: URL(string: "https://api.example.com")!,
            apiKey: nil
        )
        XCTAssertThrowsError(try resolver.registerCloudProvider(noKeyConfig, registry: registry))
    }

    func testH11_RegisterCloudSucceedsWithValidConfig() {
        let registry = ModelProviderRegistry()
        let resolver = LocalModeResolver()
        _ = resolver.resolveDefault(registry: registry)
        let cloudConfig = ModelProviderConfig(
            kind: .cloudModel,
            mode: .cloud,
            endpoint: URL(string: "https://api.example.com")!,
            apiKey: "valid-key",
            modelName: "gpt-4"
        )
        XCTAssertNoThrow(try resolver.registerCloudProvider(cloudConfig, registry: registry))
        XCTAssertEqual(registry.allProviders.count, 2)
    }

    func testH11_LocalModelProviderDefaultEndpoint() {
        let provider = LocalModelProvider()
        XCTAssertEqual(provider.config.endpoint, LocalModeDefaults.endpoint)
        XCTAssertEqual(provider.config.mode, .local)
    }

    func testH11_ModelProviderConfigDefaultsToLocal() {
        let config = ModelProviderConfig()
        XCTAssertEqual(config.mode, .local)
        XCTAssertEqual(config.endpoint, LocalModeDefaults.endpoint)
    }
}
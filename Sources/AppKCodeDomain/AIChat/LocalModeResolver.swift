import Foundation
import AppKCodeShared

public final class LocalModeResolver: @unchecked Sendable {
    public init() {}

    public func resolveDefault(registry: ModelProviderRegistry) -> ModelProvider {
        if let existing = registry.resolveDefault() {
            return existing
        }
        let localProvider = LocalModelProvider()
        registry.register(localProvider)
        return localProvider
    }

    public func registerCloudProvider(_ config: ModelProviderConfig, registry: ModelProviderRegistry) throws {
        guard config.mode == .cloud else {
            throw ChatError.networkError("Cloud Provider must have mode .cloud, got .local")
        }
        let host = config.endpoint.host ?? ""
        guard host != "127.0.0.1" && host != "localhost" else {
            throw ChatError.networkError("Cloud Provider endpoint must not be localhost")
        }
        guard let apiKey = config.apiKey, !apiKey.isEmpty else {
            throw ChatError.networkError("Cloud Provider requires non-empty apiKey")
        }
        let provider = OpenAICompatProvider(config: config)
        registry.register(provider)
    }
}
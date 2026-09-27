import Foundation
import AppKCodeShared
import AppKCodeDomain

public final class ModelProviderApplicationService: @unchecked Sendable {
    private let registry: ModelProviderRegistry
    private let resolver: LocalModeResolver

    public init(
        registry: ModelProviderRegistry = ModelProviderRegistry(),
        resolver: LocalModeResolver = LocalModeResolver()
    ) {
        self.registry = registry
        self.resolver = resolver
        _ = resolver.resolveDefault(registry: registry)
    }

    public func defaultProvider() -> ModelProvider {
        return resolver.resolveDefault(registry: registry)
    }

    public func switchProvider(_ id: ModelProviderID) throws {
        try registry.setDefault(id)
    }

    public func configureCloud(_ config: ModelProviderConfig) throws {
        try resolver.registerCloudProvider(config, registry: registry)
    }

    public func resolveProvider(_ id: ModelProviderID) -> ModelProvider? {
        return registry.resolve(id: id)
    }

    public var allProviders: [ModelProvider] {
        return registry.allProviders
    }

    public var registryRef: ModelProviderRegistry {
        return registry
    }
}
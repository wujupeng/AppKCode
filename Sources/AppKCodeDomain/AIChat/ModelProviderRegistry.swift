import Foundation
import AppKCodeShared

public final class ModelProviderRegistry: @unchecked Sendable {
    private var providers: [ModelProviderID: ModelProvider] = [:]
    private var defaultProviderID: ModelProviderID?
    private let lock = NSLock()

    public init() {}

    public func register(_ provider: ModelProvider) {
        lock.lock()
        defer { lock.unlock() }
        providers[provider.id] = provider
        if defaultProviderID == nil {
            defaultProviderID = provider.id
        }
    }

    public func resolve(id: ModelProviderID) -> ModelProvider? {
        lock.lock()
        defer { lock.unlock() }
        return providers[id]
    }

    public func resolveDefault() -> ModelProvider? {
        lock.lock()
        defer { lock.unlock() }
        guard let id = defaultProviderID else {
            return nil
        }
        return providers[id]
    }

    public func setDefault(_ id: ModelProviderID) throws {
        lock.lock()
        defer { lock.unlock() }
        guard providers[id] != nil else {
            throw ChatError.invalidResponse
        }
        defaultProviderID = id
    }

    public var allProviders: [ModelProvider] {
        lock.lock()
        defer { lock.unlock() }
        return Array(providers.values)
    }

    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return providers.isEmpty
    }
}
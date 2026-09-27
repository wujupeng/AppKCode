import Foundation
import AppKCodeShared
import AppKCodeDomain

public final class ContextAggregationService: @unchecked Sendable {
    private let aggregator: ContextAggregator
    private let providers: [ContextProvider]

    public init(providers: [ContextProvider]) {
        self.providers = providers
        self.aggregator = ContextAggregator(providers: providers)
    }

    public func aggregate(
        request: ContextRequest,
        sources: Set<ContextSource>
    ) async throws -> [ContextItem] {
        return try await aggregator.gather(context: request, sources: sources)
    }

    public func aggregate(request: ContextRequest) async throws -> [ContextItem] {
        return try await aggregator.gather(context: request)
    }

    public var availableSources: Set<ContextSource> {
        return Set(providers.map { $0.source })
    }

    public func providers(for source: ContextSource) -> [ContextProvider] {
        return providers.filter { $0.source == source }
    }
}
import Foundation
import AppKCodeShared

public final class ContextAggregator: @unchecked Sendable {
    private let providers: [ContextProvider]

    public init(providers: [ContextProvider]) {
        self.providers = providers
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        var allItems: [ContextItem] = []
        for provider in providers {
            let items = try await provider.gather(context: context)
            for item in items {
                allItems.append(item)
            }
        }
        return try enforceBudget(allItems, budget: context.budget)
    }

    public func gather(context: ContextRequest, sources: Set<ContextSource>) async throws -> [ContextItem] {
        var allItems: [ContextItem] = []
        for provider in providers where sources.contains(provider.source) {
            let items = try await provider.gather(context: context)
            for item in items {
                allItems.append(item)
            }
        }
        return try enforceBudget(allItems, budget: context.budget)
    }

    private func enforceBudget(_ items: [ContextItem], budget: ContextBudget) throws -> [ContextItem] {
        var result: [ContextItem] = []
        var totalTokens = 0
        for item in items.prefix(budget.maxItems) {
            if totalTokens + item.tokenEstimate > budget.maxTokens {
                let remaining = budget.maxTokens - totalTokens
                if remaining <= 0 {
                    break
                }
                let maxChars = remaining * 4
                let truncated = String(item.content.prefix(maxChars))
                let truncatedItem = ContextItem(
                    id: item.id,
                    source: item.source,
                    path: item.path,
                    range: item.range,
                    content: truncated,
                    metadata: item.metadata,
                    tokenEstimate: remaining
                )
                result.append(truncatedItem)
                break
            }
            result.append(item)
            totalTokens += item.tokenEstimate
        }
        return result
    }
}
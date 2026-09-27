import Foundation
import AppKCodeShared

public struct ContextItemSerializer: Sendable {
    public init() {}

    public func serialize(_ items: [ContextItem], budget: ContextBudget) -> String {
        let limited = Array(items.prefix(budget.maxItems))
        var result = ""
        var totalTokens = 0
        for item in limited {
            let header = "[source: \(item.source.rawValue), path: \(item.path?.path ?? "N/A")]"
            let (content, truncated) = truncate(item.content, budget: budget, remaining: budget.maxTokens - totalTokens, strategy: budget.truncationStrategy)
            let entry = "\(header)\n\(content)\(truncated ? "\n[truncated]" : "")\n\n"
            let entryTokens = ContextItem.estimateTokens(entry)
            totalTokens += entryTokens
            result += entry
            if totalTokens >= budget.maxTokens {
                break
            }
        }
        return result
    }

    public func serialize(_ items: [ContextItem]) -> String {
        var result = ""
        for item in items {
            let header = "[source: \(item.source.rawValue), path: \(item.path?.path ?? "N/A")]"
            result += "\(header)\n\(item.content)\n\n"
        }
        return result
    }

    private func truncate(_ content: String, budget: ContextBudget, remaining: Int, strategy: TruncationStrategy) -> (String, Bool) {
        let tokenEstimate = ContextItem.estimateTokens(content)
        if tokenEstimate <= remaining {
            return (content, false)
        }
        let maxChars = remaining * 4
        switch strategy {
        case .head:
            return (String(content.prefix(maxChars)), true)
        case .tail:
            return (String(content.suffix(maxChars)), true)
        case .headTail:
            let half = maxChars / 2
            let head = String(content.prefix(half))
            let tail = String(content.suffix(half))
            return ("\(head)\n...\n\(tail)", true)
        case .semantic:
            return (String(content.prefix(maxChars)), true)
        }
    }
}
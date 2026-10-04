import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - M11-P2-TASK-002: AgentContextBridgeImpl（G-AI 路径）
// 对应需求: m11_design.md §2.2.2.2
// 对应硬约束: H10 (Context Isolation)
// G-AI 路径上下文桥接：经 M6 ContextAggregator.gather（H10，不修改）
// 将 AgentContextRequest 转换为 M6 ContextRequest，调用 ContextAggregator.gather

// MARK: - AgentContextBridgeImpl

public final class AgentContextBridgeImpl: AgentContextBridge, @unchecked Sendable {
    private let contextAggregator: ContextAggregator

    public init(contextAggregator: ContextAggregator) {
        self.contextAggregator = contextAggregator
    }

    public func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem] {
        let contextRequest = ContextRequest(
            projectRoot: request.projectRoot,
            budget: request.budget
        )

        let items = try await contextAggregator.gather(context: contextRequest)

        return items
    }
}
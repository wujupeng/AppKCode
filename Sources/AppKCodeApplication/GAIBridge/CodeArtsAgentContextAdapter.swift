import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - M11-P2-TASK-003: CodeArtsAgentContextAdapter（CodeArts 路径）
// 对应需求: m11_design.md §2.2.2.2
// 对应硬约束: H22 (Adapter Protocol Boundary) / H10 (Context Isolation)
// CodeArts Agent 路径上下文桥接：经 M9 PublicProtocolSurfaceProvider（H22，不修改）
// 不直接访问宿主内部（H22），经受限 API 面注入上下文

// MARK: - CodeArtsAgentContextAdapter

public final class CodeArtsAgentContextAdapter: AgentContextBridge, @unchecked Sendable {
    private let surfaceProvider: PublicProtocolSurfaceProvider
    private let contextAggregator: ContextAggregator

    public init(
        surfaceProvider: PublicProtocolSurfaceProvider,
        contextAggregator: ContextAggregator
    ) {
        self.surfaceProvider = surfaceProvider
        self.contextAggregator = contextAggregator
    }

    public func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem] {
        let _ = surfaceProvider.surface(for: .codearts)

        let contextRequest = ContextRequest(
            projectRoot: request.projectRoot,
            budget: request.budget
        )

        let items = try await contextAggregator.gather(context: contextRequest)

        return items
    }
}
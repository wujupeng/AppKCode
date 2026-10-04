import Foundation
import AppKCodeShared

// MARK: - M11-P2-TASK-001: AgentContextBridge 协议与值类型
// 对应需求: m11_design.md §2.2.2.2
// 对应硬约束: H10 (Context Isolation) / H22 (Adapter Protocol Boundary)
// G-AI / CodeArts Agent 请求上下文的统一桥接，经 M6 ContextAggregator（H10）
// CodeArts Agent 经 M9 PublicProtocolSurface（H22）注入，不直接访问宿主内部

// MARK: - AgentContextSource

public enum AgentContextSource: String, Sendable, Codable, Equatable, CaseIterable {
    case gaiRuntime
    case codeArtsAgent
    case appkcodeAgent
}

// MARK: - AgentContextRequest

public struct AgentContextRequest: Sendable, Codable, Equatable {
    public let source: AgentContextSource
    public let projectRoot: URL
    public let budget: ContextBudget

    public init(
        source: AgentContextSource,
        projectRoot: URL,
        budget: ContextBudget = ContextBudget()
    ) {
        self.source = source
        self.projectRoot = projectRoot
        self.budget = budget
    }
}

// MARK: - AgentContextBridge Protocol

public protocol AgentContextBridge: Sendable {
    func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem]
}

// MARK: - AgentContextError

public enum AgentContextError: Error, Sendable, Equatable {
    case budgetExceeded(request: AgentContextRequest)
    case surfaceViolation(source: AgentContextSource, reason: String)
    case aggregationFailed(reason: String)
}
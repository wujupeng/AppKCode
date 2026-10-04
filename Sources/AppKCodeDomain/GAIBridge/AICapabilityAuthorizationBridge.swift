import Foundation
import AppKCodeShared

// MARK: - M11-P3-TASK-001.4: AICapabilityAuthorizationBridge 前置定义（仅签名，P4 实现）
// 对应需求: m11_design.md §2.2.2.4
// 对应硬约束: H28 (AI Capability 授权桥接)
// M11-P4 将补充 AICapabilityAuthorizationBridgeImpl 实现

// MARK: - AICapabilityRequest

public struct AICapabilityRequest: Sendable, Codable, Equatable {
    public let capabilityID: CapabilityID
    public let extensionID: ExtensionID
    public let input: AnyCodableValue
    public let source: AgentContextSource
    public let sessionID: AgentSessionID

    public init(
        capabilityID: CapabilityID,
        extensionID: ExtensionID,
        input: AnyCodableValue,
        source: AgentContextSource,
        sessionID: AgentSessionID
    ) {
        self.capabilityID = capabilityID
        self.extensionID = extensionID
        self.input = input
        self.source = source
        self.sessionID = sessionID
    }
}

// MARK: - AICapabilityError

public enum AICapabilityError: Error, Sendable, Equatable {
    case noContract(capabilityID: CapabilityID)
    case extensionDenied(extensionID: ExtensionID, reason: String)
    case highRiskRejected(capabilityID: CapabilityID, reason: String)
}

// MARK: - AICapabilityAuthorizationBridge Protocol（前置定义，P4 实现）

public protocol AICapabilityAuthorizationBridge: Sendable {
    func authorize(_ request: AICapabilityRequest) async throws -> AuthorizationDecision
}
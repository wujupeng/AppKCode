import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - M11-P4-TASK-002: AICapabilityAuthorizationBridgeImpl 实现
// 对应需求: m11_design.md §2.2.2.4
// 对应硬约束: H2 / H12 / H20 / H21 / H28-3 / H28-4 / H28-5
// AI Capability 调用经 M9 enforceContract (H21, H28-4) → M9 ExtensionAuthorizationIntegration (H20, H28-5) → M7 AuthorizationGate (H12, H28-3)
// 高危 → M7 AuthorizationGate → M0 ApprovalService.requestApproval (H2, 由 AuthorizationGateImpl 内部保障)

// MARK: - AICapabilityAuthorizationBridgeImpl

public final class AICapabilityAuthorizationBridgeImpl: AICapabilityAuthorizationBridge, @unchecked Sendable {
    private let contractRegistry: CapabilityContractRegistry
    private let authIntegration: ExtensionAuthorizationIntegration
    private let authGate: AuthorizationGate

    public init(
        contractRegistry: CapabilityContractRegistry,
        authIntegration: ExtensionAuthorizationIntegration,
        authGate: AuthorizationGate
    ) {
        self.contractRegistry = contractRegistry
        self.authIntegration = authIntegration
        self.authGate = authGate
    }

    // MARK: - authorize

    public func authorize(_ request: AICapabilityRequest) async throws -> AuthorizationDecision {
        // Step 1: M9 enforceContract (H21, H28-4)
        // 无 Contract 拒绝执行
        let contract: CapabilityContract
        do {
            contract = try contractRegistry.enforceContract(request.capabilityID, input: request.input)
        } catch let error as ContractViolation {
            switch error {
            case .missingContract:
                throw AICapabilityError.noContract(capabilityID: request.capabilityID)
            default:
                throw AICapabilityError.noContract(capabilityID: request.capabilityID)
            }
        }

        // Step 2: M9 ExtensionAuthorizationIntegration (H20, H28-5)
        // 默认拒绝 + 高危二次审批
        let permission = contract.requiredPermission
        let authResult = try await authIntegration.authorize(
            extensionID: request.extensionID,
            capability: request.capabilityID,
            permission: permission,
            sessionID: request.sessionID
        )

        switch authResult {
        case .allowed:
            // Extension 授权通过，低危直接放行
            return .allowed(
                decidedBy: UserID("system"),
                at: ISO8601Timestamp(),
                sha256: "capability-allowed"
            )
        case .denied(let reason):
            // Extension 拒绝 (H28-5)
            throw AICapabilityError.extensionDenied(extensionID: request.extensionID, reason: reason)
        case .requiresUserApproval:
            // Step 3: M7 AuthorizationGate (H12, H28-3)
            // 高危 → AuthorizationGate.authorize → ApprovalService.requestApproval (H2)
            return try await authorizeHighRisk(request: request, permission: permission)
        }
    }

    // MARK: - authorizeHighRisk

    private func authorizeHighRisk(
        request: AICapabilityRequest,
        permission: ExtensionPermission
    ) async throws -> AuthorizationDecision {
        let step = ActionStep(
            id: ActionStepID(),
            toolID: ToolID(request.capabilityID.rawValue),
            arguments: ToolArguments(values: [
                "capabilityID": .string(request.capabilityID.rawValue),
                "extensionID": .string(request.extensionID.rawValue)
            ]),
            description: "AI Capability: \(request.capabilityID.rawValue)",
            explanation: "High-risk capability requires user approval (risk: \(permission.riskLevel.rawValue))",
            priority: .high
        )

        let decision = try await authGate.authorize(step, session: request.sessionID)

        switch decision {
        case .allowed:
            return decision
        case .rejected(_, _, let reason):
            // 高危拒绝 (H28-3)
            throw AICapabilityError.highRiskRejected(capabilityID: request.capabilityID, reason: reason)
        case .timeout:
            // 超时视为拒绝 (H28-3)
            throw AICapabilityError.highRiskRejected(
                capabilityID: request.capabilityID,
                reason: "Approval timed out"
            )
        }
    }
}
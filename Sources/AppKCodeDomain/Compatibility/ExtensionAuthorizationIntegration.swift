import Foundation
import AppKCodeShared

// MARK: - Authorization Result (TASK-026.3)

public enum AuthorizationResult: Sendable, Codable, Equatable {
    case allowed
    case denied(reason: String)
    case requiresUserApproval(PermissionRequest)
}

// MARK: - Extension Authorization Integration (TASK-026, H20)

public final class ExtensionAuthorizationIntegration: Sendable {
    private let permissionService: ExtensionPermissionService

    public init(permissionService: ExtensionPermissionService) {
        self.permissionService = permissionService
    }

    public func authorize(
        extensionID: ExtensionID,
        capability: CapabilityID,
        permission: ExtensionPermission,
        sessionID: AgentSessionID
    ) async throws -> AuthorizationResult {
        let check = permissionService.checkPermission(extensionID, scope: permission.scope)

        if case .granted = check {
            if permission.riskLevel == .high {
                return .requiresUserApproval(
                    PermissionRequest(
                        extensionID: extensionID,
                        permission: permission,
                        justification: "High-risk capability \(capability.rawValue) requires user approval"
                    )
                )
            }
            return .allowed
        }

        if case .revoked(let reason) = check {
            return .denied(reason: reason)
        }

        if case .denied = check {
            return .requiresUserApproval(
                PermissionRequest(
                    extensionID: extensionID,
                    permission: permission,
                    justification: "Capability \(capability.rawValue) requires permission (not yet granted)"
                )
            )
        }

        return .denied(reason: "Permission not granted for capability \(capability.rawValue)")
    }

    public func authorizeAfterApproval(
        extensionID: ExtensionID,
        permission: ExtensionPermission,
        decision: PermissionDecision
    ) async throws -> AuthorizationResult {
        if case .granted(let scope, let duration) = decision {
            try await permissionService.grant(extensionID, scope: scope, duration: duration)
            return .allowed
        }
        if case .denied(let reason) = decision {
            return .denied(reason: reason)
        }
        if case .revoked(let reason) = decision {
            return .denied(reason: reason)
        }
        return .denied(reason: "Permission not granted")
    }
}
import Foundation
import AppKCodeShared

// MARK: - Extension Audit Integration (TASK-027, H23)

public final class ExtensionAuditIntegration: Sendable {
    private let auditService: AuditService

    public init(auditService: AuditService) {
        self.auditService = auditService
    }

    public func recordExtensionEvent(_ event: M9AuditEvent) async throws {
        let target = mapTarget(for: event)
        let record = AgentAuditRecord(
            sessionID: event.sessionID ?? AgentSessionID("__extension__"),
            tool: ToolID("__extension__"),
            arguments: ToolArguments(),
            target: target,
            approval: .allowed(decidedBy: UserID("system"), at: ISO8601Timestamp(), sha256: "extension-audit"),
            result: mapResult(for: event),
            error: mapError(for: event),
            sha256: "m9-audit-\(event.kind.rawValue)"
        )
        try await auditService.record(record)
    }

    private func mapTarget(for event: M9AuditEvent) -> AuditTarget {
        if let extID = event.extensionID {
            switch event.kind {
            case .extensionManifestLoaded, .extensionEnabled, .extensionDisabled,
                 .extensionUnloaded, .extensionInvoked, .extensionFailed, .extensionIncompatible:
                return .extension_(extID, action: mapExtensionAction(event.kind))
            case .adapterInstantiated, .adapterDisposed, .adapterAPICalled,
                 .adapterDegraded, .adapterBoundaryViolation:
                return .adapter(AdapterID(extID.rawValue), action: mapAdapterAction(event.kind))
            case .capabilityInvoked, .capabilityDenied:
                return .capability(CapabilityID(extID.rawValue), extensionID: extID)
            case .contractNegotiated, .contractNegotiationFailed:
                return .contractNegotiation(extID)
            case .permissionRequested, .permissionGranted, .permissionDenied, .permissionRevoked:
                return .permissionDecision(extID)
            case .versionNegotiationSucceeded, .versionNegotiationFailed:
                return .contractNegotiation(extID)
            }
        }
        return .none
    }

    private func mapExtensionAction(_ kind: M9AuditEventKind) -> ExtensionAuditAction {
        switch kind {
        case .extensionManifestLoaded: return .loading
        case .extensionEnabled: return .enabled
        case .extensionDisabled: return .disabled
        case .extensionUnloaded: return .unloaded
        case .extensionInvoked: return .invoked
        case .extensionFailed: return .failed
        case .extensionIncompatible: return .incompatible
        default: return .loaded
        }
    }

    private func mapAdapterAction(_ kind: M9AuditEventKind) -> AdapterAuditAction {
        switch kind {
        case .adapterInstantiated: return .instantiated
        case .adapterDisposed: return .disposed
        case .adapterAPICalled: return .apiCalled
        case .adapterDegraded: return .degraded
        case .adapterBoundaryViolation: return .boundaryViolation
        default: return .apiCalled
        }
    }

    private func mapResult(for event: M9AuditEvent) -> AuditResultSummary {
        switch event.kind {
        case .extensionFailed, .extensionIncompatible, .contractNegotiationFailed,
             .permissionDenied, .permissionRevoked, .versionNegotiationFailed,
             .adapterBoundaryViolation, .capabilityDenied:
            return .failure(code: 1, message: event.kind.rawValue)
        default:
            return .success
        }
    }

    private func mapError(for event: M9AuditEvent) -> String? {
        switch event.kind {
        case .extensionFailed, .extensionIncompatible, .contractNegotiationFailed,
             .permissionDenied, .permissionRevoked, .versionNegotiationFailed,
             .adapterBoundaryViolation, .capabilityDenied:
            return event.kind.rawValue
        default:
            return nil
        }
    }
}
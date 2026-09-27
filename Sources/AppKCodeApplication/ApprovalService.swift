import Foundation
import CryptoKit
import AppKCodeShared
import AppKCodeInfrastructure

public final class ApprovalService: AppApprovalService, @unchecked Sendable {
    private let auditStore: JSONLAuditStore
    private let timeoutSeconds: TimeInterval
    private var pendingRequests: [UUID: CheckedContinuation<ApprovalDecision, Never>] = [:]
    private let lock = NSLock()

    public init(auditStore: JSONLAuditStore, timeoutSeconds: TimeInterval = 600) {
        self.auditStore = auditStore
        self.timeoutSeconds = timeoutSeconds
    }

    public func classify(operation: OperationDescriptor) -> RiskLevel {
        switch operation.kind {
        case .fileWrite: return .high
        case .commandExec: return .high
        case .networkAccess: return .high
        case .gitPush: return .high
        case .gitReset: return .high
        case .gitRebase: return .high
        case .mcpToolCall: return .high
        case .readFile: return .readOnly
        case .gitStatus: return .readOnly
        case .gitDiff: return .readOnly
        }
    }

    public func requestApproval(_ payload: ApprovalPayload) async throws -> ApprovalDecision {
        let operationKind = inferOperationKind(from: payload)
        let descriptor = OperationDescriptor(kind: operationKind, payload: payload)
        let riskLevel = classify(operation: descriptor)

        if riskLevel == .readOnly {
            return .allow
        }

        let payloadHash = HashUtil.sha256(payload.description + payload.reason + payload.sessionID.rawValue)
        let request = ApprovalRequest(
            payload: payload,
            riskLevel: riskLevel,
            payloadHash: payloadHash
        )

        NotificationCenter.default.post(name: .appkApprovalRequested, object: request)

        let decision = await waitForDecision(requestID: request.id)

        let auditRecord = AuditRecord(
            timestamp: ISO8601Timestamp(),
            operation: payload.description,
            decision: decision,
            decidedBy: UserID("user"),
            sha256: payloadHash,
            sessionID: payload.sessionID
        )
        try? await auditStore.append(auditRecord)

        switch decision {
        case .allow: return .allow
        case .reject: throw AppKError.approvalRejected(reason: payload.reason)
        case .timeout: throw AppKError.approvalTimeout(operation: payload.description)
        case .pending: throw AppKError.approvalTimeout(operation: payload.description)
        }
    }

    public func auditTrail(session: AgentSessionID) async throws -> [AuditRecord] {
        try await auditStore.query(filter: AuditQueryFilter(sessionID: session))
    }

    public func resolveApproval(requestID: UUID, decision: ApprovalDecision) {
        lock.lock()
        if let continuation = pendingRequests.removeValue(forKey: requestID) {
            continuation.resume(returning: decision)
        }
        lock.unlock()
    }

    private func waitForDecision(requestID: UUID) async -> ApprovalDecision {
        return await withCheckedContinuation { (continuation: CheckedContinuation<ApprovalDecision, Never>) in
            lock.lock()
            pendingRequests[requestID] = continuation
            lock.unlock()

            Task { [timeoutSeconds] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                self.lock.lock()
                if let cont = self.pendingRequests.removeValue(forKey: requestID) {
                    cont.resume(returning: .timeout)
                }
                self.lock.unlock()
            }
        }
    }

    private func inferOperationKind(from payload: ApprovalPayload) -> OperationKind {
        if payload.description.lowercased().contains("git push") {
            return .gitPush(remote: "origin")
        }
        if payload.description.lowercased().contains("write") || payload.description.lowercased().contains("modify") {
            return .fileWrite(paths: payload.affectedFiles)
        }
        if payload.description.lowercased().contains("command") || payload.description.lowercased().contains("exec") {
            return .commandExec(command: payload.description, args: [])
        }
        return .fileWrite(paths: payload.affectedFiles)
    }
}

extension Notification.Name {
    static let appkApprovalRequested = Notification.Name("AppKApprovalRequested")
    static let appkApprovalResolved = Notification.Name("AppKApprovalResolved")
}
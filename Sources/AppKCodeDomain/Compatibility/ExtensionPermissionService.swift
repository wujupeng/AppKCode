import Foundation
import AppKCodeShared

// MARK: - Extension Permission Service Protocol (TASK-025.1, H20)

public protocol ExtensionPermissionService: Sendable {
    func requestPermission(_ request: PermissionRequest) async throws -> PermissionDecision
    func checkPermission(_ extensionID: ExtensionID, scope: PermissionScope) -> PermissionDecision
    func grant(_ extensionID: ExtensionID, scope: PermissionScope, duration: PermissionDuration) async throws
    func revoke(_ extensionID: ExtensionID, scope: PermissionScope, reason: String) async throws
    func listPermissions(_ extensionID: ExtensionID) -> [ExtensionPermission]
}

// MARK: - Extension Permission Service Impl (TASK-025.2~025.5, H20)

public final class ExtensionPermissionServiceImpl: ExtensionPermissionService, @unchecked Sendable {
    private let lock = NSLock()
    private var permissions: [ExtensionID: [PermissionScopeKey: PermissionDecision]] = [:]

    public init() {}

    public func requestPermission(_ request: PermissionRequest) async throws -> PermissionDecision {
        let permission = request.permission

        if permission.riskLevel == .high {
            return .pending
        }

        if permission.riskLevel == .readOnly {
            let decision: PermissionDecision = .granted(scope: permission.scope, duration: .session)
            try await grant(request.extensionID, scope: permission.scope, duration: .session)
            return decision
        }

        return .pending
    }

    public func checkPermission(_ extensionID: ExtensionID, scope: PermissionScope) -> PermissionDecision {
        lock.lock()
        defer { lock.unlock() }

        let key = PermissionScopeKey(scope: scope)
        if let decision = permissions[extensionID]?[key] {
            if case .granted = decision { return decision }
            if case .revoked = decision { return decision }
            return decision
        }
        return .denied(reason: "Permission not granted (H20: default deny)")
    }

    public func grant(_ extensionID: ExtensionID, scope: PermissionScope, duration: PermissionDuration) async throws {
        lock.lock()
        defer { lock.unlock() }

        let key = PermissionScopeKey(scope: scope)
        if permissions[extensionID] == nil {
            permissions[extensionID] = [:]
        }
        permissions[extensionID]?[key] = .granted(scope: scope, duration: duration)
    }

    public func revoke(_ extensionID: ExtensionID, scope: PermissionScope, reason: String) async throws {
        lock.lock()
        defer { lock.unlock() }

        let key = PermissionScopeKey(scope: scope)
        permissions[extensionID]?[key] = .revoked(reason: reason)
    }

    public func listPermissions(_ extensionID: ExtensionID) -> [ExtensionPermission] {
        lock.lock()
        defer { lock.unlock() }

        guard let scopeMap = permissions[extensionID] else { return [] }
        return scopeMap.compactMap { _, decision in
            if case .granted(let scope, _) = decision {
                return ExtensionPermission(scope: scope, operations: [.read], riskLevel: .low, requiresApproval: false)
            }
            return nil
        }
    }
}

// MARK: - Permission Scope Key (internal hashing helper)

struct PermissionScopeKey: Hashable {
    let scope: PermissionScope
}
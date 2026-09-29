import Foundation

// MARK: - File Access Level (TASK-005.3)

public enum FileAccessLevel: String, Sendable, Codable, Hashable {
    case readOnly
    case readWrite
    case execute
}

// MARK: - Git Operation (TASK-005.3)

public enum GitOperation: String, Sendable, Codable, Hashable {
    case status
    case diff
    case log
    case add
    case commit
    case push
    case reset
    case rebase
}

// MARK: - Permission Operation (TASK-005.3)

public enum PermissionOperation: String, Sendable, Codable, Hashable {
    case read
    case write
    case execute
    case list
    case subscribe
}

// MARK: - Permission Scope (TASK-005.2)

public enum PermissionScope: Sendable, Codable, Hashable {
    case filesystem(path: String, access: FileAccessLevel)
    case network(endpoint: String)
    case process(command: String)
    case git(operations: [GitOperation])
    case environment(variables: [String])
    case clipboard
    case ui
}

// MARK: - Permission Risk Level (TASK-005.4, H20)

public enum PermissionRiskLevel: String, Sendable, Codable, Hashable {
    case readOnly
    case low
    case high
}

// MARK: - Extension Permission (TASK-005.1, H20)

public struct ExtensionPermission: Sendable, Codable, Hashable {
    public let scope: PermissionScope
    public let operations: [PermissionOperation]
    public let riskLevel: PermissionRiskLevel
    public let requiresApproval: Bool

    public init(
        scope: PermissionScope,
        operations: [PermissionOperation],
        riskLevel: PermissionRiskLevel,
        requiresApproval: Bool
    ) {
        self.scope = scope
        self.operations = operations
        self.riskLevel = riskLevel
        self.requiresApproval = requiresApproval
    }
}

// MARK: - Permission Request ID (TASK-005.5)

public struct PermissionRequestID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Permission Request (TASK-005.5)

public struct PermissionRequest: Sendable, Codable, Hashable {
    public let id: PermissionRequestID
    public let extensionID: ExtensionID
    public let permission: ExtensionPermission
    public let justification: String
    public let timestamp: ISO8601Timestamp

    public init(
        id: PermissionRequestID = PermissionRequestID(),
        extensionID: ExtensionID,
        permission: ExtensionPermission,
        justification: String,
        timestamp: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.id = id
        self.extensionID = extensionID
        self.permission = permission
        self.justification = justification
        self.timestamp = timestamp
    }
}

// MARK: - Permission Duration (TASK-005.6)

public enum PermissionDuration: String, Sendable, Codable, Hashable {
    case session
    case permanent
    case untilRevoked
}

// MARK: - Permission Decision (TASK-005.6, H20)

public enum PermissionDecision: Sendable, Codable, Hashable {
    case granted(scope: PermissionScope, duration: PermissionDuration)
    case denied(reason: String)
    case pending
    case revoked(reason: String)
}
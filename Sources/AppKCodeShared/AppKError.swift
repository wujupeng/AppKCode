import Foundation

public enum AppKError: Error, Sendable, Equatable {
    case modelUnavailable(endpoint: String, cause: String)
    case approvalRejected(reason: String)
    case approvalTimeout(operation: String)
    case sessionNotFound(sessionID: String)
    case permissionDenied(path: String)
    case localModeViolation(endpoint: String)
    case fileNotFound(url: String)
    case encodingFailed(detail: String)
    case sandboxCreationFailed(sessionID: String)
    case invalidConfiguration(key: String)
    case toolExecutionFailed(tool: String, cause: String)

    public var localizedDescription: String {
        switch self {
        case .modelUnavailable(let endpoint, let cause):
            return "Model unavailable at \(endpoint): \(cause)"
        case .approvalRejected(let reason):
            return "Approval rejected: \(reason)"
        case .approvalTimeout(let operation):
            return "Approval timed out for: \(operation)"
        case .sessionNotFound(let sessionID):
            return "Session not found: \(sessionID)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .localModeViolation(let endpoint):
            return "Local mode violation: endpoint \(endpoint) is not local"
        case .fileNotFound(let url):
            return "File not found: \(url)"
        case .encodingFailed(let detail):
            return "Encoding failed: \(detail)"
        case .sandboxCreationFailed(let sessionID):
            return "Sandbox creation failed for session: \(sessionID)"
        case .invalidConfiguration(let key):
            return "Invalid configuration: \(key)"
        case .toolExecutionFailed(let tool, let cause):
            return "Tool '\(tool)' execution failed: \(cause)"
        }
    }
}
import Foundation

public typealias SHA256 = String

public struct ISO8601Timestamp: Sendable, Equatable, Hashable, Comparable, Codable {
    public let rawValue: String

    public init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.rawValue = formatter.string(from: Date())
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func < (lhs: ISO8601Timestamp, rhs: ISO8601Timestamp) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct UserID: Sendable, Equatable, Hashable {
    public let rawValue: String
    public init(_ value: String) { self.rawValue = value }
}

public struct AgentSessionID: Sendable, Equatable, Hashable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

public struct TraceID: Sendable, Equatable, Hashable {
    public let rawValue: UUID
    public init() { self.rawValue = UUID() }
    public init(_ value: UUID) { self.rawValue = value }
}

public struct SpanID: Sendable, Equatable, Hashable {
    public let rawValue: UUID
    public init() { self.rawValue = UUID() }
    public init(_ value: UUID) { self.rawValue = value }
}

public enum LogLevel: String, Sendable, Comparable {
    case trace, debug, info, warn, error, fatal
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.trace, .debug, .info, .warn, .error, .fatal]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public struct WorkspaceHandle: Sendable {
    public let rootURL: URL
    public let openedAt: ISO8601Timestamp
    public init(rootURL: URL, openedAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.rootURL = rootURL
        self.openedAt = openedAt
    }
}

public struct FileChangeProposal: Sendable, Equatable {
    public let fileURL: URL
    public let originalContent: String?
    public let proposedContent: String
    public let reason: String
    public init(fileURL: URL, originalContent: String?, proposedContent: String, reason: String) {
        self.fileURL = fileURL
        self.originalContent = originalContent
        self.proposedContent = proposedContent
        self.reason = reason
    }
}

public struct AgentReport: Sendable, Equatable {
    public let summary: String
    public let details: String
    public init(summary: String, details: String) {
        self.summary = summary
        self.details = details
    }
}
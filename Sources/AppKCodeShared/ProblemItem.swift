import Foundation

public struct ProblemItem: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let file: String
    public let line: Int
    public let column: Int
    public let severity: ProblemSeverity
    public let message: String
    public let source: ProblemSource

    public init(id: UUID = UUID(), file: String, line: Int, column: Int = 0, severity: ProblemSeverity, message: String, source: ProblemSource) {
        self.id = id
        self.file = file
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
        self.source = source
    }

    public var locationText: String {
        column > 0 ? "\(file):\(line):\(column)" : "\(file):\(line)"
    }
}

public enum ProblemSeverity: String, Sendable, Equatable, Comparable {
    case error
    case warning
    case info
    case hint

    public static func < (lhs: ProblemSeverity, rhs: ProblemSeverity) -> Bool {
        let order: [ProblemSeverity] = [.error, .warning, .info, .hint]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public enum ProblemSource: String, Sendable, Equatable {
    case lsp
    case build
    case test
}
import Foundation

public enum DiagnosticSeverity: Int, Codable, Sendable, Equatable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

public struct Diagnostic: Codable, Equatable, Sendable {
    public let range: LSPRange
    public let severity: DiagnosticSeverity
    public let code: String?
    public let source: String?
    public let message: String

    public init(range: LSPRange, severity: DiagnosticSeverity, code: String? = nil,
                source: String? = nil, message: String) {
        self.range = range
        self.severity = severity
        self.code = code
        self.source = source
        self.message = message
    }
}
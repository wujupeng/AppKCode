import Foundation

public struct ContextMetadata: Sendable, Equatable, Codable {
    public let language: String?
    public let fileSize: Int?
    public let modifiedAt: ISO8601Timestamp?
    public let symbolName: String?
    public let diagnosticCount: Int?

    public init(
        language: String? = nil,
        fileSize: Int? = nil,
        modifiedAt: ISO8601Timestamp? = nil,
        symbolName: String? = nil,
        diagnosticCount: Int? = nil
    ) {
        self.language = language
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.symbolName = symbolName
        self.diagnosticCount = diagnosticCount
    }

    public static let empty = ContextMetadata()
}

public struct SourceRange: Sendable, Equatable, Codable {
    public let startLine: Int
    public let endLine: Int
    public let startColumn: Int
    public let endColumn: Int

    public init(startLine: Int, endLine: Int, startColumn: Int = 0, endColumn: Int = 0) {
        self.startLine = startLine
        self.endLine = endLine
        self.startColumn = startColumn
        self.endColumn = endColumn
    }
}
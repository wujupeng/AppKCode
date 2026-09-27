import Foundation

public struct LSPTextEdit: Codable, Equatable, Sendable {
    public let range: LSPRange
    public let newText: String

    public init(range: LSPRange, newText: String) {
        self.range = range
        self.newText = newText
    }
}

public struct LSPWorkspaceEdit: Codable, Equatable, Sendable {
    public let changes: [String: [LSPTextEdit]]

    public init(changes: [String: [LSPTextEdit]] = [:]) {
        self.changes = changes
    }
}
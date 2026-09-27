import Foundation

public enum SyntaxTokenType: String, Sendable {
    case keyword
    case string
    case comment
    case number
    case `operator`
    case identifier
    case type
    case function
    case punctuation
    case `attribute`
    case plain
    case heading
    case link
    case key
    case value
}

public struct SyntaxToken: Hashable, Sendable {
    public let type: SyntaxTokenType
    public let range: TextRange
    public let text: String

    public init(type: SyntaxTokenType, range: TextRange, text: String) {
        self.type = type
        self.range = range
        self.text = text
    }
}

public protocol DomainSyntaxHighlighter: Sendable {
    var language: String { get }
    func tokenize(_ text: String) -> [SyntaxToken]
}
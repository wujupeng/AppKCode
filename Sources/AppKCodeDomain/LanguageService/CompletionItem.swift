import Foundation

public enum CompletionItemKind: Int, Codable, Sendable, Equatable {
    case text = 1
    case method = 2
    case function = 3
    case field = 4
    case variable = 5
    case `class` = 6
    case interface = 7
    case module = 8
    case property = 9
    case unit = 10
    case value = 11
    case `enum` = 12
    case keyword = 13
    case snippet = 14
    case color = 15
    case file = 16
    case reference = 17
    case folder = 18
    case enumMember = 19
    case constant = 20
    case `struct` = 21
    case event = 22
    case `operator` = 23
    case typeParameter = 24
}

public struct CompletionItem: Codable, Equatable, Sendable {
    public let label: String
    public let kind: CompletionItemKind?
    public let detail: String?
    public let documentation: String?
    public let insertText: String?
    public let sortText: String?

    public init(label: String, kind: CompletionItemKind? = nil, detail: String? = nil,
                documentation: String? = nil, insertText: String? = nil, sortText: String? = nil) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.insertText = insertText
        self.sortText = sortText
    }
}
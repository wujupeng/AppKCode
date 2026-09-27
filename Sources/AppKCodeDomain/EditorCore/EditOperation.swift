import Foundation

public enum EditOperationType: String, Sendable {
    case insert
    case delete
    case replace
}

public struct EditOperation: Sendable {
    public let type: EditOperationType
    public let range: TextRange
    public let text: String
    public let originalText: String

    public init(type: EditOperationType, range: TextRange, text: String, originalText: String) {
        self.type = type
        self.range = range
        self.text = text
        self.originalText = originalText
    }

    public var inverse: EditOperation {
        switch type {
        case .insert:
            return EditOperation(type: .delete, range: range, text: originalText, originalText: text)
        case .delete:
            return EditOperation(type: .insert, range: range, text: originalText, originalText: text)
        case .replace:
            return EditOperation(type: .replace, range: range, text: originalText, originalText: text)
        }
    }
}
import Foundation

public enum ContextSource: String, Sendable, Equatable, Codable, CaseIterable {
    case currentFile
    case selectedText
    case currentSymbol
    case openTabs
    case workspace
    case diagnostics
    case gitDiff
    case buildTestResults
}
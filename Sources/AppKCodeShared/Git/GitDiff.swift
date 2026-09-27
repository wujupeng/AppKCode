import Foundation

public enum GitDiffLineKind: Sendable, Equatable {
    case context
    case added
    case deleted
}

public struct GitDiffLine: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: GitDiffLineKind
    public let oldLineNumber: Int?
    public let newLineNumber: Int?
    public let content: String

    public init(id: UUID = UUID(), kind: GitDiffLineKind, oldLineNumber: Int?, newLineNumber: Int?, content: String) {
        self.id = id
        self.kind = kind
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.content = content
    }
}

public struct GitDiffHunk: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let oldStartLine: Int
    public let oldLineCount: Int
    public let newStartLine: Int
    public let newLineCount: Int
    public let lines: [GitDiffLine]

    public init(id: UUID = UUID(), oldStartLine: Int, oldLineCount: Int, newStartLine: Int, newLineCount: Int, lines: [GitDiffLine]) {
        self.id = id
        self.oldStartLine = oldStartLine
        self.oldLineCount = oldLineCount
        self.newStartLine = newStartLine
        self.newLineCount = newLineCount
        self.lines = lines
    }
}

public struct GitFileDiff: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let oldPath: String
    public let newPath: String
    public let hunks: [GitDiffHunk]
    public let addedLinesCount: Int
    public let deletedLinesCount: Int

    public init(id: UUID = UUID(), oldPath: String, newPath: String, hunks: [GitDiffHunk], addedLinesCount: Int, deletedLinesCount: Int) {
        self.id = id
        self.oldPath = oldPath
        self.newPath = newPath
        self.hunks = hunks
        self.addedLinesCount = addedLinesCount
        self.deletedLinesCount = deletedLinesCount
    }
}
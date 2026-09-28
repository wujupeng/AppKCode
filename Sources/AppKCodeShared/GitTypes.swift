import Foundation

public struct GitStatus: Sendable, Equatable {
    public let branchName: String?
    public let modifiedCount: Int
    public let stagedCount: Int
    public let untrackedCount: Int
    public init(branchName: String?, modifiedCount: Int, stagedCount: Int, untrackedCount: Int) {
        self.branchName = branchName
        self.modifiedCount = modifiedCount
        self.stagedCount = stagedCount
        self.untrackedCount = untrackedCount
    }
}

public struct SearchHit: Sendable, Equatable {
    public let filePath: String
    public let lineNumber: Int
    public let matchedLine: String
    public init(filePath: String, lineNumber: Int, matchedLine: String) {
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.matchedLine = matchedLine
    }
}

public struct SearchOptions: Sendable, Equatable {
    public let caseSensitive: Bool
    public let wholeWord: Bool
    public let regex: Bool
    public let filePattern: String?
    public init(caseSensitive: Bool = false, wholeWord: Bool = false, regex: Bool = false, filePattern: String? = nil) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.regex = regex
        self.filePattern = filePattern
    }
}

public struct DiffHunk: Sendable, Equatable, Codable {
    public let oldStart: Int
    public let oldEnd: Int
    public let newStart: Int
    public let newEnd: Int
    public let lines: [DiffLine]
    public init(oldStart: Int, oldEnd: Int, newStart: Int, newEnd: Int, lines: [DiffLine]) {
        self.oldStart = oldStart
        self.oldEnd = oldEnd
        self.newStart = newStart
        self.newEnd = newEnd
        self.lines = lines
    }
}

public struct DiffLine: Sendable, Equatable, Codable {
    public let content: String
    public let changeType: DiffChangeType
    public init(content: String, changeType: DiffChangeType) {
        self.content = content
        self.changeType = changeType
    }
}

public enum DiffChangeType: String, Sendable, Equatable, Codable {
    case context
    case added
    case removed
}

public struct FileTreeNode: Sendable, Equatable, Hashable {
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public init(name: String, url: URL, isDirectory: Bool) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
    }
}

public struct EditorDocumentState: Sendable, Equatable {
    public let url: URL
    public let content: String
    public let isDirty: Bool
    public let encoding: StringEncoding
    public init(url: URL, content: String, isDirty: Bool, encoding: StringEncoding = .utf8) {
        self.url = url
        self.content = content
        self.isDirty = isDirty
        self.encoding = encoding
    }
}

public enum StringEncoding: Sendable, Equatable {
    case utf8
    case ascii
    case latin1
}
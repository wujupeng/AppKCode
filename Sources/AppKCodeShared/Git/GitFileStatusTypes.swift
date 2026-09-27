import Foundation

public enum GitFileStatus: String, Sendable, Equatable {
    case modified
    case staged
    case untracked
    case deleted
    case renamed
    case typeChanged
    case conflicted
}

public struct GitFileStatusItem: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let path: String
    public let status: GitFileStatus
    public let staged: Bool
    public let oldPath: String?

    public init(id: UUID = UUID(), path: String, status: GitFileStatus, staged: Bool, oldPath: String? = nil) {
        self.id = id
        self.path = path
        self.status = status
        self.staged = staged
        self.oldPath = oldPath
    }
}

public enum GitOperationKind: Sendable, Equatable {
    case status
    case diff
    case log
    case branchList
    case stage(paths: [String])
    case unstage(paths: [String])
    case checkout(branch: String)
    case checkoutNewBranch(name: String)
    case branchCreate(name: String)
    case branchDelete(name: String)
    case fetch(remote: String)
    case pull(remote: String, branch: String)
    case commit(message: String, paths: [String])
    case push(remote: String, branch: String)
    case resetHard(target: String)
    case rebase(target: String)
}

public enum GitRiskLevel: Sendable, Equatable {
    case readOnly
    case low
    case high

    public static func classify(_ kind: GitOperationKind) -> GitRiskLevel {
        switch kind {
        case .status, .diff, .log, .branchList, .fetch: return .readOnly
        case .stage, .unstage, .checkout, .checkoutNewBranch, .branchCreate, .branchDelete, .pull: return .low
        case .commit, .push, .resetHard, .rebase: return .high
        }
    }
}
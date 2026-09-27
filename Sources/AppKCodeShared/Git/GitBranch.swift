import Foundation

public struct GitBranchInfo: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let isCurrent: Bool
    public let isRemote: Bool
    public let upstreamTracking: String?
    public let lastCommitSha: String
    public let lastCommitDate: Date

    public init(id: UUID = UUID(), name: String, isCurrent: Bool, isRemote: Bool, upstreamTracking: String?, lastCommitSha: String, lastCommitDate: Date) {
        self.id = id
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
        self.upstreamTracking = upstreamTracking
        self.lastCommitSha = lastCommitSha
        self.lastCommitDate = lastCommitDate
    }
}
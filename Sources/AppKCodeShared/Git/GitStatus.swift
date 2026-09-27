import Foundation

public struct GitRepositoryStatus: Sendable, Equatable {
    public let isRepository: Bool
    public let currentBranch: String?
    public let upstreamBranch: String?
    public let aheadCount: Int
    public let behindCount: Int
    public let files: [GitFileStatusItem]
    public let hasUncommittedChanges: Bool

    public init(isRepository: Bool, currentBranch: String?, upstreamBranch: String?, aheadCount: Int, behindCount: Int, files: [GitFileStatusItem], hasUncommittedChanges: Bool) {
        self.isRepository = isRepository
        self.currentBranch = currentBranch
        self.upstreamBranch = upstreamBranch
        self.aheadCount = aheadCount
        self.behindCount = behindCount
        self.files = files
        self.hasUncommittedChanges = hasUncommittedChanges
    }

    public static let notARepository = GitRepositoryStatus(
        isRepository: false, currentBranch: nil, upstreamBranch: nil,
        aheadCount: 0, behindCount: 0, files: [], hasUncommittedChanges: false
    )
}
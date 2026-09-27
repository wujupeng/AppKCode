import Foundation
import AppKCodeShared

public protocol GitServiceProtocol: AnyObject {
    func detectRepository(at path: URL) async -> GitRepositoryStatus
    func isGitRepository(at path: URL) async -> Bool

    func getStatus(at repoURL: URL) async throws -> GitRepositoryStatus

    func getWorkingDiff(at repoURL: URL, filePath: String) async throws -> GitFileDiff?
    func getStagedDiff(at repoURL: URL, filePath: String) async throws -> GitFileDiff?
    func getHeadDiff(at repoURL: URL, filePath: String) async throws -> GitFileDiff?
    func getCommitDiff(at repoURL: URL, sha: String) async throws -> [GitFileDiff]

    func stage(paths: [String], at repoURL: URL) async throws
    func unstage(paths: [String], at repoURL: URL) async throws
    func stageAll(at repoURL: URL) async throws

    func commit(message: String, paths: [String], at repoURL: URL) async throws -> String

    func listBranches(at repoURL: URL) async throws -> [GitBranchInfo]
    func createBranch(name: String, at repoURL: URL, from startPoint: String?) async throws
    func deleteBranch(name: String, at repoURL: URL, force: Bool) async throws

    func checkout(branch: String, at repoURL: URL) async throws
    func checkoutNewBranch(name: String, from startPoint: String?, at repoURL: URL) async throws

    func getLog(at repoURL: URL, limit: Int, skip: Int) async throws -> [GitCommitInfo]
    func getCommitInfo(sha: String, at repoURL: URL) async throws -> GitCommitInfo

    func fetch(remote: String, at repoURL: URL) async throws
    func pull(remote: String, branch: String, at repoURL: URL) async throws
    func push(remote: String, branch: String, at repoURL: URL) async throws
}
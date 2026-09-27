import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class GitServiceImpl: GitServiceProtocol, @unchecked Sendable {
    private let commandRunner: GitCommandRunner
    private let outputParser: GitOutputParser
    private let repositoryDetector: GitRepositoryDetector
    private let approvalService: AppApprovalService?

    public init(commandRunner: GitCommandRunner = GitCommandRunner(),
                approvalService: AppApprovalService? = nil) {
        self.commandRunner = commandRunner
        self.outputParser = GitOutputParser()
        self.repositoryDetector = GitRepositoryDetector(commandRunner: commandRunner)
        self.approvalService = approvalService
    }

    public func detectRepository(at path: URL) async -> GitRepositoryStatus {
        await repositoryDetector.detectRepository(at: path)
    }

    public func isGitRepository(at path: URL) async -> Bool {
        repositoryDetector.isGitRepository(at: path)
    }

    public func getStatus(at repoURL: URL) async throws -> GitRepositoryStatus {
        let statusOutput = try await commandRunner.run(
            arguments: ["status", "--porcelain=v1", "--branch"],
            at: repoURL
        )
        let (branch, upstream, ahead, behind, files) = outputParser.parseStatus(statusOutput)
        return GitRepositoryStatus(
            isRepository: true, currentBranch: branch, upstreamBranch: upstream,
            aheadCount: ahead, behindCount: behind, files: files,
            hasUncommittedChanges: !files.isEmpty
        )
    }

    public func getWorkingDiff(at repoURL: URL, filePath: String) async throws -> GitFileDiff? {
        let output = try await commandRunner.run(
            arguments: ["diff", "--", filePath],
            at: repoURL
        )
        let diffs = outputParser.parseDiff(output)
        return diffs.first
    }

    public func getStagedDiff(at repoURL: URL, filePath: String) async throws -> GitFileDiff? {
        let output = try await commandRunner.run(
            arguments: ["diff", "--cached", "--", filePath],
            at: repoURL
        )
        let diffs = outputParser.parseDiff(output)
        return diffs.first
    }

    public func getHeadDiff(at repoURL: URL, filePath: String) async throws -> GitFileDiff? {
        let output = try await commandRunner.run(
            arguments: ["diff", "HEAD", "--", filePath],
            at: repoURL
        )
        let diffs = outputParser.parseDiff(output)
        return diffs.first
    }

    public func getCommitDiff(at repoURL: URL, sha: String) async throws -> [GitFileDiff] {
        let output = try await commandRunner.run(
            arguments: ["diff", "\(sha)^", sha],
            at: repoURL
        )
        return outputParser.parseDiff(output)
    }

    public func stage(paths: [String], at repoURL: URL) async throws {
        _ = try await commandRunner.run(
            arguments: ["add", "--"] + paths,
            at: repoURL
        )
    }

    public func unstage(paths: [String], at repoURL: URL) async throws {
        _ = try await commandRunner.run(
            arguments: ["reset", "HEAD", "--"] + paths,
            at: repoURL
        )
    }

    public func stageAll(at repoURL: URL) async throws {
        _ = try await commandRunner.run(
            arguments: ["add", "--all"],
            at: repoURL
        )
    }

    public func commit(message: String, paths: [String], at repoURL: URL) async throws -> String {
        if let approvalService = approvalService {
            let payload = ApprovalPayload(
                description: "Git commit: \(message)",
                affectedFiles: paths.map { URL(fileURLWithPath: $0) },
                reason: "Git commit operation",
                sessionID: AgentSessionID()
            )
            let decision = try await approvalService.requestApproval(payload)
            guard decision == .allow else {
                throw AppKError.approvalRejected(reason: "Git commit rejected")
            }
        }

        var args = ["commit", "-m", message]
        if !paths.isEmpty {
            args += ["--"] + paths
        }
        _ = try await commandRunner.run(arguments: args, at: repoURL)

        let shaOutput = try await commandRunner.run(
            arguments: ["rev-parse", "HEAD"],
            at: repoURL
        )
        return shaOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func listBranches(at repoURL: URL) async throws -> [GitBranchInfo] {
        let output = try await commandRunner.run(
            arguments: ["branch", "--list", "--all"],
            at: repoURL
        )
        return outputParser.parseBranches(output)
    }

    public func createBranch(name: String, at repoURL: URL, from startPoint: String?) async throws {
        var args = ["branch", name]
        if let startPoint = startPoint { args.append(startPoint) }
        _ = try await commandRunner.run(arguments: args, at: repoURL)
    }

    public func deleteBranch(name: String, at repoURL: URL, force: Bool) async throws {
        let flag = force ? "-D" : "-d"
        _ = try await commandRunner.run(arguments: ["branch", flag, name], at: repoURL)
    }

    public func checkout(branch: String, at repoURL: URL) async throws {
        _ = try await commandRunner.run(arguments: ["checkout", branch], at: repoURL)
    }

    public func checkoutNewBranch(name: String, from startPoint: String?, at repoURL: URL) async throws {
        var args = ["checkout", "-b", name]
        if let startPoint = startPoint { args.append(startPoint) }
        _ = try await commandRunner.run(arguments: args, at: repoURL)
    }

    public func getLog(at repoURL: URL, limit: Int, skip: Int) async throws -> [GitCommitInfo] {
        let format = outputParser.logFormat
        var args = ["log", "--format=\(format)", "-n", "\(limit)"]
        if skip > 0 { args += ["--skip", "\(skip)"] }
        let output = try await commandRunner.run(arguments: args, at: repoURL)
        return outputParser.parseLog(output)
    }

    public func getCommitInfo(sha: String, at repoURL: URL) async throws -> GitCommitInfo {
        let format = outputParser.logFormat
        let output = try await commandRunner.run(
            arguments: ["log", "--format=\(format)", "-n", "1", sha],
            at: repoURL
        )
        let commits = outputParser.parseLog(output)
        guard let commit = commits.first else {
            throw AppKError.toolExecutionFailed(tool: "git log", cause: "commit not found: \(sha)")
        }
        return commit
    }

    public func fetch(remote: String, at repoURL: URL) async throws {
        _ = try await commandRunner.run(arguments: ["fetch", remote], at: repoURL)
    }

    public func pull(remote: String, branch: String, at repoURL: URL) async throws {
        _ = try await commandRunner.run(arguments: ["pull", remote, branch], at: repoURL)
    }

    public func push(remote: String, branch: String, at repoURL: URL) async throws {
        if let approvalService = approvalService {
            let payload = ApprovalPayload(
                description: "Git push: \(remote) \(branch)",
                affectedFiles: [],
                reason: "Git push operation",
                sessionID: AgentSessionID()
            )
            let decision = try await approvalService.requestApproval(payload)
            guard decision == .allow else {
                throw AppKError.approvalRejected(reason: "Git push rejected")
            }
        }
        _ = try await commandRunner.run(arguments: ["push", remote, branch], at: repoURL)
    }
}
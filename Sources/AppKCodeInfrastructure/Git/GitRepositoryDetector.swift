import Foundation
import AppKCodeShared

public final class GitRepositoryDetector: @unchecked Sendable {
    private let commandRunner: GitCommandRunner

    public init(commandRunner: GitCommandRunner = GitCommandRunner()) {
        self.commandRunner = commandRunner
    }

    public func isGitRepository(at path: URL) -> Bool {
        let gitDir = path.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir.path)
    }

    public func detectRepository(at path: URL) async -> GitRepositoryStatus {
        guard isGitRepository(at: path) else {
            return .notARepository
        }

        do {
            let (_, _, exitCode) = try await commandRunner.runWithExitCode(
                arguments: ["rev-parse", "--is-inside-work-tree"],
                at: path
            )
            guard exitCode == 0 else {
                return .notARepository
            }

            let statusOutput = try await commandRunner.run(
                arguments: ["status", "--porcelain=v1", "--branch"],
                at: path
            )

            let parser = GitOutputParser()
            let (branch, upstream, ahead, behind, files) = parser.parseStatus(statusOutput)

            return GitRepositoryStatus(
                isRepository: true,
                currentBranch: branch,
                upstreamBranch: upstream,
                aheadCount: ahead,
                behindCount: behind,
                files: files,
                hasUncommittedChanges: !files.isEmpty
            )
        } catch {
            return .notARepository
        }
    }
}
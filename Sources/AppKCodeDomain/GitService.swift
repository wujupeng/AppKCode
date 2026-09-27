import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class GitService: @unchecked Sendable {
    private let processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    public func detectRepo(at url: URL) -> Bool {
        let gitDir = url.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir.path)
    }

    public func status(of repo: URL) async throws -> GitStatus {
        let branchResult = try await processRunner.run("git", args: ["rev-parse", "--abbrev-ref", "HEAD"], in: repo)
        let branchName: String? = branchResult.exitCode == 0
            ? branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        let statusResult = try await processRunner.run("git", args: ["status", "--porcelain"], in: repo)
        var modified = 0, staged = 0, untracked = 0
        if statusResult.exitCode == 0 {
            for line in statusResult.stdout.split(separator: "\n") {
                guard line.count >= 2 else { continue }
                let x = line[line.startIndex]
                let y = line[line.index(after: line.startIndex)]
                if x == "?" && y == "?" { untracked += 1 }
                else if x == " " { modified += 1 }
                else { staged += 1 }
            }
        }
        return GitStatus(branchName: branchName, modifiedCount: modified, stagedCount: staged, untrackedCount: untracked)
    }

    public func currentCommitHash(of repo: URL) async throws -> String {
        let result = try await processRunner.run("git", args: ["rev-parse", "HEAD"], in: repo)
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func initRepo(at url: URL) async throws {
        let result = try await processRunner.run("git", args: ["init"], in: url)
        if result.exitCode != 0 {
            throw AppKError.toolExecutionFailed(tool: "git init", cause: result.stderr)
        }
    }
}
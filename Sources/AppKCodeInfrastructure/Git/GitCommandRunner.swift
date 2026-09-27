import Foundation
import AppKCodeShared

public final class GitCommandRunner: @unchecked Sendable {
    private let processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    public func run(arguments: [String], at repoURL: URL) async throws -> String {
        let command = Command(executable: "git", arguments: arguments, workingDirectory: repoURL)
        let result = try await processRunner.run(command)
        if result.exitCode != 0 {
            throw AppKError.toolExecutionFailed(tool: "git", cause: result.stderr)
        }
        return result.stdout
    }

    public func runWithExitCode(arguments: [String], at repoURL: URL) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let command = Command(executable: "git", arguments: arguments, workingDirectory: repoURL)
        let result = try await processRunner.run(command)
        return (result.stdout, result.stderr, result.exitCode)
    }

    public func runStreaming(arguments: [String], at repoURL: URL) -> AsyncStream<ProcessOutput> {
        let command = Command(executable: "git", arguments: arguments, workingDirectory: repoURL)
        return processRunner.runStreaming(command)
    }
}
import Foundation
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

public final class ToolRouter: AppToolRouter, @unchecked Sendable {
    private let approvalService: ApprovalService
    private let processRunner: ProcessRunner
    private let ripgrepClient: RipgrepClient

    public init(approvalService: ApprovalService, processRunner: ProcessRunner, ripgrepClient: RipgrepClient) {
        self.approvalService = approvalService
        self.processRunner = processRunner
        self.ripgrepClient = ripgrepClient
    }

    public func execute(_ call: ToolCall, session: AgentSessionID) async throws -> ToolResult {
        switch call {
        case .readFile(let url):
            return try await executeReadFile(url: url)

        case .writeFile(let url, let content):
            return try await executeWriteFile(url: url, content: content, session: session)

        case .searchCode(let query, let directory):
            return try await executeSearch(query: query, directory: directory)

        case .runBuild(let tool, let directory):
            return try await executeBuild(tool: tool, directory: directory, session: session)

        case .runTest(let tool, let directory):
            return try await executeTest(tool: tool, directory: directory, session: session)

        case .gitStatus(let repo):
            return try await executeGitStatus(repo: repo)

        case .gitDiff(let repo):
            return try await executeGitDiff(repo: repo)

        case .lspRequest:
            return ToolResult(success: false, output: "", error: "LSP not available in M0")

        case .mcpCall:
            return ToolResult(success: false, output: "", error: "MCP not available in M0")
        }
    }

    private func executeReadFile(url: URL) async throws -> ToolResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppKError.fileNotFound(url: url.path)
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        return ToolResult(success: true, output: content)
    }

    private func executeWriteFile(url: URL, content: String, session: AgentSessionID) async throws -> ToolResult {
        let payload = ApprovalPayload(
            description: "Write to \(url.lastPathComponent)",
            affectedFiles: [url],
            reason: "Agent file modification",
            sessionID: session
        )
        let decision = try await approvalService.requestApproval(payload)
        guard decision == .allow else {
            return ToolResult(success: false, output: "", error: "Write rejected")
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
        return ToolResult(success: true, output: "File written: \(url.lastPathComponent)")
    }

    private func executeSearch(query: String, directory: URL) async throws -> ToolResult {
        let hits = try await ripgrepClient.search(query: query, in: directory)
        let output = hits.map { "\($0.filePath):\($0.lineNumber): \($0.matchedLine)" }.joined(separator: "\n")
        return ToolResult(success: true, output: output)
    }

    private func executeBuild(tool: BuildTool, directory: URL, session: AgentSessionID) async throws -> ToolResult {
        let payload = ApprovalPayload(
            description: "Run build: \(tool.buildCommand)",
            affectedFiles: [],
            reason: "Build execution",
            sessionID: session
        )
        let decision = try await approvalService.requestApproval(payload)
        guard decision == .allow else {
            return ToolResult(success: false, output: "", error: "Build rejected")
        }
        let result = try await processRunner.run(tool.binaryName, args: Array(tool.buildCommand.split(separator: " ").dropFirst().map(String.init)), in: directory)
        return ToolResult(success: result.exitCode == 0, output: result.stdout, error: result.exitCode == 0 ? nil : result.stderr)
    }

    private func executeTest(tool: BuildTool, directory: URL, session: AgentSessionID) async throws -> ToolResult {
        let payload = ApprovalPayload(
            description: "Run tests: \(tool.testCommand)",
            affectedFiles: [],
            reason: "Test execution",
            sessionID: session
        )
        let decision = try await approvalService.requestApproval(payload)
        guard decision == .allow else {
            return ToolResult(success: false, output: "", error: "Test run rejected")
        }
        let result = try await processRunner.run(tool.binaryName, args: Array(tool.testCommand.split(separator: " ").dropFirst().map(String.init)), in: directory)
        return ToolResult(success: result.exitCode == 0, output: result.stdout, error: result.exitCode == 0 ? nil : result.stderr)
    }

    private func executeGitStatus(repo: URL) async throws -> ToolResult {
        let result = try await processRunner.run("git", args: ["status", "--porcelain"], in: repo)
        return ToolResult(success: result.exitCode == 0, output: result.stdout, error: result.exitCode == 0 ? nil : result.stderr)
    }

    private func executeGitDiff(repo: URL) async throws -> ToolResult {
        let result = try await processRunner.run("git", args: ["diff"], in: repo)
        return ToolResult(success: result.exitCode == 0, output: result.stdout, error: result.exitCode == 0 ? nil : result.stderr)
    }
}
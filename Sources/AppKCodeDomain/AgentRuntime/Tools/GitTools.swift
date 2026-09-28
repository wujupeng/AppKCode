import Foundation
import AppKCodeShared

// MARK: - Git Status Tool (TASK-015.1)

public final class GitStatusTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("git.status"),
        category: .git,
        permission: .readOnly,
        parameters: [
            ToolParameterSchema(name: "projectRoot", type: .filePath, required: true, description: "Git repository root")
        ],
        returnType: .object,
        description: "Get git status",
        version: "1.0.0"
    )

    private let gitService: GitServiceProtocol

    public init(gitService: GitServiceProtocol) {
        self.gitService = gitService
    }

    public func validate(arguments: ToolArguments) -> ValidationResult {
        if arguments.filePath("projectRoot") == nil {
            return .invalid(reason: "Missing required parameter: projectRoot", missingFields: ["projectRoot"])
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let projectRoot = arguments.filePath("projectRoot") else {
            throw AppKError.invalidConfiguration(key: "projectRoot")
        }
        let status = try await gitService.getStatus(at: projectRoot)
        return ToolOutput(text: "Branch: \(status.currentBranch ?? "unknown"), Files: \(status.files.count), Uncommitted: \(status.hasUncommittedChanges)")
    }
}

// MARK: - Git Diff Tool (TASK-015.2)

public final class GitDiffTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("git.diff"),
        category: .git,
        permission: .readOnly,
        parameters: [
            ToolParameterSchema(name: "projectRoot", type: .filePath, required: true, description: "Git repository root"),
            ToolParameterSchema(name: "filePath", type: .string, required: false, description: "Specific file path")
        ],
        returnType: .string,
        description: "Get git diff",
        version: "1.0.0"
    )

    private let gitService: GitServiceProtocol

    public init(gitService: GitServiceProtocol) {
        self.gitService = gitService
    }

    public func validate(arguments: ToolArguments) -> ValidationResult {
        if arguments.filePath("projectRoot") == nil {
            return .invalid(reason: "Missing required parameter: projectRoot", missingFields: ["projectRoot"])
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let projectRoot = arguments.filePath("projectRoot") else {
            throw AppKError.invalidConfiguration(key: "projectRoot")
        }
        let filePath = arguments.string("filePath") ?? ""
        if let diff = try await gitService.getWorkingDiff(at: projectRoot, filePath: filePath) {
            let lines = diff.hunks.flatMap { $0.lines }.map { $0.content }
            return ToolOutput(text: lines.joined(separator: "\n"))
        }
        return ToolOutput(text: "No changes")
    }
}

// MARK: - Git Commit Tool (TASK-015.3, H12)

public final class GitCommitTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("git.commit"),
        category: .git,
        permission: .high,
        parameters: [
            ToolParameterSchema(name: "projectRoot", type: .filePath, required: true, description: "Git repository root"),
            ToolParameterSchema(name: "message", type: .string, required: true, description: "Commit message"),
            ToolParameterSchema(name: "paths", type: .array(of: .filePath), required: false, description: "Files to commit")
        ],
        returnType: .string,
        description: "Git commit",
        version: "1.0.0"
    )

    private let gitService: GitServiceProtocol

    public init(gitService: GitServiceProtocol) {
        self.gitService = gitService
    }

    public func validate(arguments: ToolArguments) -> ValidationResult {
        var missing: [String] = []
        if arguments.filePath("projectRoot") == nil { missing.append("projectRoot") }
        if arguments.string("message") == nil { missing.append("message") }
        if !missing.isEmpty {
            return .invalid(reason: "Missing required parameters", missingFields: missing)
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let projectRoot = arguments.filePath("projectRoot"),
              let message = arguments.string("message") else {
            throw AppKError.invalidConfiguration(key: "projectRoot or message")
        }
        var paths: [String] = []
        if let arr = arguments.array("paths") {
            for v in arr {
                if case .filePath(let u) = v { paths.append(u.path) }
            }
        }
        let sha = try await gitService.commit(message: message, paths: paths, at: projectRoot)
        return ToolOutput(text: "Committed: \(sha)")
    }
}

// MARK: - Git Push Tool (TASK-015.4, H12)

public final class GitPushTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("git.push"),
        category: .git,
        permission: .high,
        parameters: [
            ToolParameterSchema(name: "projectRoot", type: .filePath, required: true, description: "Git repository root"),
            ToolParameterSchema(name: "remote", type: .string, required: false, description: "Remote name", defaultValue: .string("origin")),
            ToolParameterSchema(name: "branch", type: .string, required: false, description: "Branch name")
        ],
        returnType: .string,
        description: "Git push",
        version: "1.0.0"
    )

    private let gitService: GitServiceProtocol

    public init(gitService: GitServiceProtocol) {
        self.gitService = gitService
    }

    public func validate(arguments: ToolArguments) -> ValidationResult {
        if arguments.filePath("projectRoot") == nil {
            return .invalid(reason: "Missing required parameter: projectRoot", missingFields: ["projectRoot"])
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let projectRoot = arguments.filePath("projectRoot") else {
            throw AppKError.invalidConfiguration(key: "projectRoot")
        }
        let remote = arguments.string("remote") ?? "origin"
        let branch = arguments.string("branch") ?? ""
        try await gitService.push(remote: remote, branch: branch, at: projectRoot)
        return ToolOutput(text: "Pushed to \(remote)/\(branch)")
    }
}

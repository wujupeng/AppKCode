import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - Tool Registry Application Service (TASK-023)

public final class ToolRegistryService: @unchecked Sendable {
    private let registry: ToolRegistry

    public init(registry: ToolRegistry) {
        self.registry = registry
    }

    public func registerBuiltins(
        gitService: GitServiceProtocol,
        buildService: BuildService,
        testService: TestService
    ) throws {
        try registry.register(FileReadTool())
        try registry.register(FileWriteTool())
        try registry.register(FileDeleteTool())
        try registry.register(CommandExecuteTool())
        try registry.register(GitStatusTool(gitService: gitService))
        try registry.register(GitDiffTool(gitService: gitService))
        try registry.register(GitCommitTool(gitService: gitService))
        try registry.register(GitPushTool(gitService: gitService))
        try registry.register(BuildProjectTool(buildService: buildService))
        try registry.register(TestRunnerTool(testService: testService))
    }

    public func listTools() -> [ToolSchema] {
        registry.listAll()
    }

    public func listToolsByPermission(_ permission: ToolPermission) -> [ToolSchema] {
        registry.listByPermission(permission)
    }

    public func listToolsByCategory(_ category: ToolCategory) -> [ToolSchema] {
        registry.listByCategory(category)
    }
}
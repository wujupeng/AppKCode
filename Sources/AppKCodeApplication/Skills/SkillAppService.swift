import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - Skill App Service (TASK-025)

public final class SkillAppService: @unchecked Sendable {
    private let registry: SkillRegistry
    private let executor: SkillExecutor

    public init(registry: SkillRegistry, executor: SkillExecutor) {
        self.registry = registry
        self.executor = executor
    }

    public func listSkills() -> [SkillManifest] {
        registry.listAll()
    }

    public func skillDetail(_ id: SkillID) -> SkillManifest? {
        registry.resolve(id)
    }

    public func invokeSkill(_ request: SkillInvocationRequest) async throws -> SkillExecutionResult {
        try await executor.execute(request)
    }

    public func reloadSkills(_ dir: URL) async throws -> ReloadResult {
        try await registry.reload(dir)
    }
}
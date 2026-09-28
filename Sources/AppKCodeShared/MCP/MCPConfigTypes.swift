import Foundation

// MARK: - MCP Runtime Config (TASK-006.1)

public struct MCPRuntimeConfig: Sendable, Codable, Equatable {
    public let servers: [MCPServerConfig]
    public let defaultTimeoutSeconds: Int
    public let maxConcurrentInvocations: Int
    public let hotReload: Bool

    public init(
        servers: [MCPServerConfig] = [],
        defaultTimeoutSeconds: Int = 30,
        maxConcurrentInvocations: Int = 10,
        hotReload: Bool = true
    ) {
        self.servers = servers
        self.defaultTimeoutSeconds = defaultTimeoutSeconds
        self.maxConcurrentInvocations = maxConcurrentInvocations
        self.hotReload = hotReload
    }
}

// MARK: - Skills Runtime Config (TASK-006.2)

public struct SkillsRuntimeConfig: Sendable, Codable, Equatable {
    public let builtinSkillsPath: URL
    public let customSkillsPath: URL?
    public let hotReload: Bool
    public let defaultExecutionPolicy: SkillExecutionPolicy

    public init(
        builtinSkillsPath: URL,
        customSkillsPath: URL? = nil,
        hotReload: Bool = true,
        defaultExecutionPolicy: SkillExecutionPolicy = SkillExecutionPolicy()
    ) {
        self.builtinSkillsPath = builtinSkillsPath
        self.customSkillsPath = customSkillsPath
        self.hotReload = hotReload
        self.defaultExecutionPolicy = defaultExecutionPolicy
    }
}

// MARK: - Rules Runtime Config (TASK-006.3)

public struct RulesRuntimeConfig: Sendable, Codable, Equatable {
    public let globalRulesPath: URL
    public let projectRulesPath: URL?
    public let hotReload: Bool
    public let strictConflictDetection: Bool

    public init(
        globalRulesPath: URL,
        projectRulesPath: URL? = nil,
        hotReload: Bool = true,
        strictConflictDetection: Bool = true
    ) {
        self.globalRulesPath = globalRulesPath
        self.projectRulesPath = projectRulesPath
        self.hotReload = hotReload
        self.strictConflictDetection = strictConflictDetection
    }
}
import Foundation

// MARK: - Skill ID (TASK-003.1)

public struct SkillID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - JSON Schema Items (indirect for recursion)

public indirect enum JSONSchemaItems: Sendable, Codable, Equatable {
    case property(JSONSchemaProperty)
}

// MARK: - JSON Schema Property (TASK-003.1)

public struct JSONSchemaProperty: Sendable, Codable, Equatable {
    public let type: String
    public let description: String?
    public let items: JSONSchemaItems?
    public let enumValues: [AnyCodableValue]?

    public init(
        type: String,
        description: String? = nil,
        items: JSONSchemaItems? = nil,
        enumValues: [AnyCodableValue]? = nil
    ) {
        self.type = type
        self.description = description
        self.items = items
        self.enumValues = enumValues
    }
}

// MARK: - JSON Schema (TASK-003.1)

public struct JSONSchema: Sendable, Codable, Equatable {
    public let type: String
    public let properties: [String: JSONSchemaProperty]
    public let required: [String]
    public let description: String?

    public init(
        type: String,
        properties: [String: JSONSchemaProperty] = [:],
        required: [String] = [],
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.description = description
    }
}

// MARK: - Skill Execution Policy (TASK-003.3, H16)

public struct SkillExecutionPolicy: Sendable, Codable, Equatable {
    public let maxSteps: Int
    public let maxDurationSeconds: Int
    public let requireApproval: Bool
    public let allowedCategories: [ToolCategory]
    public let sandboxed: Bool

    public init(
        maxSteps: Int = 20,
        maxDurationSeconds: Int = 300,
        requireApproval: Bool = true,
        allowedCategories: [ToolCategory] = [.fileRead, .fileWrite, .command, .git, .buildTest, .context, .search],
        sandboxed: Bool = true
    ) {
        self.maxSteps = maxSteps
        self.maxDurationSeconds = maxDurationSeconds
        self.requireApproval = requireApproval
        self.allowedCategories = allowedCategories
        self.sandboxed = sandboxed
    }
}

// MARK: - Skill Manifest (TASK-003.2)

public struct SkillManifest: Sendable, Codable, Equatable {
    public let id: SkillID
    public let name: String
    public let description: String
    public let version: String
    public let inputSchema: JSONSchema
    public let outputSchema: JSONSchema
    public let executionPolicy: SkillExecutionPolicy
    public let allowedTools: [ToolID]?
    public let metadata: [String: String]

    public init(
        id: SkillID = SkillID(),
        name: String,
        description: String,
        version: String,
        inputSchema: JSONSchema,
        outputSchema: JSONSchema,
        executionPolicy: SkillExecutionPolicy,
        allowedTools: [ToolID]? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.executionPolicy = executionPolicy
        self.allowedTools = allowedTools
        self.metadata = metadata
    }
}

// MARK: - Skill Error (TASK-003.4)

public enum SkillError: Error, Sendable, Codable, Equatable {
    case invalidInput(reason: String)
    case toolNotAllowed(ToolID)
    case maxStepsExceeded
    case executionPolicyViolation(String)
    case underlyingError(String)
}

// MARK: - Skill Execution Result (TASK-003.4)

public enum SkillExecutionResult: Sendable, Codable, Equatable {
    case success(output: AnyCodableValue, evidence: [EvidenceRecordID])
    case failure(error: SkillError, partialEvidence: [EvidenceRecordID])
    case timedOut
    case cancelled
}

// MARK: - Skill Invocation Request (TASK-003.5)

public struct SkillInvocationRequest: Sendable, Codable, Equatable {
    public let skillID: SkillID
    public let input: AnyCodableValue
    public let sessionID: AgentSessionID

    public init(skillID: SkillID, input: AnyCodableValue, sessionID: AgentSessionID) {
        self.skillID = skillID
        self.input = input
        self.sessionID = sessionID
    }
}
import Foundation

// MARK: - Capability ID (TASK-002.1)

public struct CapabilityID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Capability Category (TASK-002.1)

public enum CapabilityCategory: Sendable, Codable, Hashable {
    case extension_
    case agent
    case tool
    case command
    case language
    case resource
    case other(String)
}

// MARK: - Capability (TASK-002.2, H21)

public struct Capability: Sendable, Codable, Hashable {
    public let id: CapabilityID
    public let name: String
    public let description: String
    public let category: CapabilityCategory
    public let contractID: CapabilityContractID
    public let version: SemVer
    public let deprecated: Bool
    public let replacement: CapabilityID?

    public init(
        id: CapabilityID,
        name: String,
        description: String,
        category: CapabilityCategory,
        contractID: CapabilityContractID,
        version: SemVer,
        deprecated: Bool = false,
        replacement: CapabilityID? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.contractID = contractID
        self.version = version
        self.deprecated = deprecated
        self.replacement = replacement
    }
}

// MARK: - Capability Descriptor (TASK-002.3)

public struct CapabilityDescriptor: Sendable, Codable, Equatable {
    public let capability: Capability
    public let providedBy: ExtensionID
    public let inputSchema: JSONSchema
    public let outputSchema: JSONSchema
    public let permission: ExtensionPermission

    public init(
        capability: Capability,
        providedBy: ExtensionID,
        inputSchema: JSONSchema,
        outputSchema: JSONSchema,
        permission: ExtensionPermission
    ) {
        self.capability = capability
        self.providedBy = providedBy
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.permission = permission
    }
}

// MARK: - Capability Error (TASK-002.4)

public enum CapabilityError: Error, Sendable, Codable, Hashable {
    case contractNotFound
    case contractViolation(reason: String)
    case permissionDenied
    case versionIncompatible
    case underlyingError(String)
}

// MARK: - Capability Invocation Result (TASK-002.4)

public enum CapabilityInvocationResult: Sendable, Codable, Equatable {
    case success(output: AnyCodableValue, evidence: [String])
    case failure(error: CapabilityError)
    case degraded(reason: String, partialOutput: AnyCodableValue?)
    case denied(reason: String)
}

// MARK: - Capability Invocation Request (TASK-002.5)

public struct CapabilityInvocationRequest: Sendable, Codable, Equatable {
    public let capabilityID: CapabilityID
    public let extensionID: ExtensionID
    public let input: AnyCodableValue
    public let sessionID: AgentSessionID

    public init(
        capabilityID: CapabilityID,
        extensionID: ExtensionID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) {
        self.capabilityID = capabilityID
        self.extensionID = extensionID
        self.input = input
        self.sessionID = sessionID
    }
}
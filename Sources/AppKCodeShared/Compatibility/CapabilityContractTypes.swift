import Foundation

// MARK: - Capability Contract ID (TASK-003.1)

public struct CapabilityContractID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Protocol Kind (TASK-003.1)

public enum ProtocolKind: Sendable, Codable, Hashable {
    case codeartsAgent
    case vscode
    case jetbrains
    case lsp
    case mcp
    case custom(String)
}

// MARK: - Degradation Strategy (TASK-003.2)

public enum DegradationStrategy: String, Sendable, Codable, Hashable {
    case rosetta
    case shim
    case disable
    case promptOnly
}

// MARK: - API Name (TASK-003.4)

public struct APIName: Hashable, Sendable, Codable {
    public let namespace: String
    public let method: String

    public init(namespace: String, method: String) {
        self.namespace = namespace
        self.method = method
    }
}

// MARK: - Test Case ID (TASK-003.4)

public struct TestCaseID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Capability Contract (TASK-003.3, H21)

public struct CapabilityContract: Sendable, Codable, Equatable {
    public let id: CapabilityContractID
    public let name: String
    public let protocolKind: ProtocolKind
    public let supportedAPIs: [APIName]
    public let degradationStrategy: DegradationStrategy
    public let testCases: [TestCaseID]
    public let inputSchema: JSONSchema
    public let outputSchema: JSONSchema
    public let requiredPermission: ExtensionPermission
    public let minHostVersion: SemVer
    public let maxHostVersion: SemVer?

    public init(
        id: CapabilityContractID,
        name: String,
        protocolKind: ProtocolKind,
        supportedAPIs: [APIName],
        degradationStrategy: DegradationStrategy,
        testCases: [TestCaseID],
        inputSchema: JSONSchema,
        outputSchema: JSONSchema,
        requiredPermission: ExtensionPermission,
        minHostVersion: SemVer,
        maxHostVersion: SemVer? = nil
    ) {
        self.id = id
        self.name = name
        self.protocolKind = protocolKind
        self.supportedAPIs = supportedAPIs
        self.degradationStrategy = degradationStrategy
        self.testCases = testCases
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.requiredPermission = requiredPermission
        self.minHostVersion = minHostVersion
        self.maxHostVersion = maxHostVersion
    }
}

// MARK: - Contract Test Failure (TASK-003.5)

public struct ContractTestFailure: Sendable, Codable, Hashable {
    public let testCaseID: TestCaseID
    public let reason: String

    public init(testCaseID: TestCaseID, reason: String) {
        self.testCaseID = testCaseID
        self.reason = reason
    }
}

// MARK: - Contract Test Result (TASK-003.5)

public struct ContractTestResult: Sendable, Codable, Hashable {
    public let contractID: CapabilityContractID
    public let passed: Bool
    public let failures: [ContractTestFailure]
    public let timestamp: ISO8601Timestamp

    public init(
        contractID: CapabilityContractID,
        passed: Bool,
        failures: [ContractTestFailure] = [],
        timestamp: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.contractID = contractID
        self.passed = passed
        self.failures = failures
        self.timestamp = timestamp
    }
}

// MARK: - Contract Violation (TASK-003.6, H21)

public enum ContractViolation: Error, Sendable, Codable, Hashable {
    case missingContract(capabilityID: CapabilityID)
    case invalidInputSchema(reason: String)
    case invalidOutputSchema(reason: String)
    case permissionMismatch
    case versionOutOfRange(host: SemVer, minRequired: SemVer, maxAllowed: SemVer?)
    case testCasesEmpty
}
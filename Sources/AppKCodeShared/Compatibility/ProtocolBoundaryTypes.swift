import Foundation

// MARK: - Public API (TASK-007.1, H22)

public struct PublicAPI: Sendable, Codable, Hashable {
    public let name: APIName
    public let signature: String
    public let permission: ExtensionPermission
    public let since: SemVer

    public init(
        name: APIName,
        signature: String,
        permission: ExtensionPermission,
        since: SemVer
    ) {
        self.name = name
        self.signature = signature
        self.permission = permission
        self.since = since
    }
}

// MARK: - Public Protocol Surface (TASK-007.1, H22)

public struct PublicProtocolSurface: Sendable, Codable, Hashable {
    public let apis: [PublicAPI]
    public let version: SemVer
    public let deprecated: [APIName]

    public init(
        apis: [PublicAPI],
        version: SemVer,
        deprecated: [APIName] = []
    ) {
        self.apis = apis
        self.version = version
        self.deprecated = deprecated
    }
}

// MARK: - Protocol Access Kind (TASK-007.2)

public enum ProtocolAccessKind: String, Sendable, Codable, Hashable {
    case publicAPI
    case privateInternal
    case forbidden
}

// MARK: - Protocol Access Record (TASK-007.2, H22)

public struct ProtocolAccessRecord: Sendable, Codable, Hashable {
    public let adapterID: AdapterID
    public let api: APIName
    public let accessKind: ProtocolAccessKind
    public let timestamp: ISO8601Timestamp
    public let allowed: Bool

    public init(
        adapterID: AdapterID,
        api: APIName,
        accessKind: ProtocolAccessKind,
        timestamp: ISO8601Timestamp = ISO8601Timestamp(),
        allowed: Bool
    ) {
        self.adapterID = adapterID
        self.api = api
        self.accessKind = accessKind
        self.timestamp = timestamp
        self.allowed = allowed
    }
}

// MARK: - Protocol Boundary Violation (TASK-007.3, H22)

public struct ProtocolBoundaryViolation: Sendable, Codable, Hashable {
    public let adapterID: AdapterID
    public let attemptedAPI: APIName
    public let accessKind: ProtocolAccessKind
    public let reason: String
    public let timestamp: ISO8601Timestamp

    public init(
        adapterID: AdapterID,
        attemptedAPI: APIName,
        accessKind: ProtocolAccessKind,
        reason: String,
        timestamp: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.adapterID = adapterID
        self.attemptedAPI = attemptedAPI
        self.accessKind = accessKind
        self.reason = reason
        self.timestamp = timestamp
    }
}

// MARK: - API Call (TASK-007.4)

public struct APICall: Sendable, Codable, Equatable {
    public let api: APIName
    public let arguments: [String: AnyCodableValue]

    public init(api: APIName, arguments: [String: AnyCodableValue] = [:]) {
        self.api = api
        self.arguments = arguments
    }
}

// MARK: - Degradation Response (TASK-007.4)

public struct DegradationResponse: Sendable, Codable, Equatable {
    public let originalCall: APICall
    public let strategy: DegradationStrategy
    public let message: String
    public let partialResult: AnyCodableValue?

    public init(
        originalCall: APICall,
        strategy: DegradationStrategy,
        message: String,
        partialResult: AnyCodableValue? = nil
    ) {
        self.originalCall = originalCall
        self.strategy = strategy
        self.message = message
        self.partialResult = partialResult
    }
}
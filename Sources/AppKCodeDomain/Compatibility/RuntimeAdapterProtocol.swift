import Foundation
import AppKCodeShared

// MARK: - Adapter Instance (TASK-020.2)

public struct AdapterInstance: Sendable, Codable, Equatable {
    public let id: AdapterID
    public let extensionID: ExtensionID
    public let createdAt: ISO8601Timestamp

    public init(id: AdapterID = AdapterID(), extensionID: ExtensionID, createdAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.id = id
        self.extensionID = extensionID
        self.createdAt = createdAt
    }
}

// MARK: - Runtime Adapter Protocol (TASK-020.1, H22)

public protocol RuntimeAdapter: Sendable {
    var descriptor: AdapterDescriptor { get }
    var state: AdapterState { get }
    func instantiate(_ context: AdapterInstantiationContext) async throws -> AdapterInstance
    func dispose() async throws
    func invokeCapability(_ id: CapabilityID, input: AnyCodableValue, sessionID: AgentSessionID) async throws -> CapabilityInvocationResult
    func interceptUnhandledAPI(_ call: APICall) -> DegradationResponse
}

// MARK: - Public Protocol Surface Provider (TASK-020.3, H22)

public protocol PublicProtocolSurfaceProvider: Sendable {
    func surface(for kind: AdapterKind) -> PublicProtocolSurface
}

// MARK: - Adapter Factory (TASK-020.4)

public protocol AdapterFactory: Sendable {
    func canHandle(_ kind: AdapterKind) -> Bool
    func create(kind: AdapterKind, surface: PublicProtocolSurface) -> RuntimeAdapter
}
import Foundation
import AppKCodeShared

// MARK: - Custom Adapter (TASK-024, H22)

public final class CustomAdapter: RuntimeAdapter, @unchecked Sendable {
    public let descriptor: AdapterDescriptor
    private var _state: AdapterState = .uninitialized
    private let lock = NSLock()
    private var instance: AdapterInstance?
    private let customKind: String

    public init(customKind: String, surface: PublicProtocolSurface) {
        self.customKind = customKind
        self.descriptor = AdapterDescriptor(
            id: AdapterID(),
            kind: .custom(customKind),
            name: "Custom Adapter (\(customKind))",
            supportedProtocol: .custom(customKind),
            hostVersion: surface.version,
            capabilities: []
        )
    }

    public var state: AdapterState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    public func instantiate(_ context: AdapterInstantiationContext) async throws -> AdapterInstance {
        lock.lock()
        _state = .initialized
        lock.unlock()

        let inst = AdapterInstance(extensionID: context.manifest.id)
        lock.lock()
        self.instance = inst
        _state = .active
        lock.unlock()
        return inst
    }

    public func dispose() async throws {
        lock.lock()
        _state = .disposed
        instance = nil
        lock.unlock()
    }

    public func invokeCapability(
        _ id: CapabilityID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) async throws -> CapabilityInvocationResult {
        return .degraded(reason: "Custom adapter (\(customKind)): capability execution requires AuthorizationGate + AuditService integration", partialOutput: nil)
    }

    public func interceptUnhandledAPI(_ call: APICall) -> DegradationResponse {
        return DegradationResponse(
            originalCall: call,
            strategy: .promptOnly,
            message: "Custom API \(call.api.namespace).\(call.api.method) not natively supported",
            partialResult: nil
        )
    }
}
import Foundation
import AppKCodeShared

// MARK: - CodeArts Adapter (TASK-021, H22)

public final class CodeArtsAdapter: RuntimeAdapter, @unchecked Sendable {
    public let descriptor: AdapterDescriptor
    private var _state: AdapterState = .uninitialized
    private let lock = NSLock()
    private var instance: AdapterInstance?

    public init(surface: PublicProtocolSurface) {
        self.descriptor = AdapterDescriptor(
            id: AdapterID(),
            kind: .codearts,
            name: "CodeArts Agent Adapter",
            supportedProtocol: .codeartsAgent,
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
        return .degraded(reason: "CodeArts adapter: capability execution requires AuthorizationGate + AuditService integration (Phase 4)", partialOutput: nil)
    }

    public func interceptUnhandledAPI(_ call: APICall) -> DegradationResponse {
        return DegradationResponse(
            originalCall: call,
            strategy: .promptOnly,
            message: "CodeArts API \(call.api.namespace).\(call.api.method) not natively supported",
            partialResult: nil
        )
    }
}
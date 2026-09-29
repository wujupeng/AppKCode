import Foundation
import AppKCodeShared

// MARK: - JetBrains Adapter (TASK-023, H22, M9 skeleton)

public final class JetBrainsAdapter: RuntimeAdapter, @unchecked Sendable {
    public let descriptor: AdapterDescriptor
    private var _state: AdapterState = .uninitialized
    private let lock = NSLock()
    private var instance: AdapterInstance?

    private static let supportedAPIs: Set<String> = [
        "com.intellij.openapi.project.Project",
        "com.intellij.openapi.editor.Editor",
        "com.intellij.openapi.vfs.VirtualFile",
        "com.intellij.execution.RunManager"
    ]

    public init(surface: PublicProtocolSurface) {
        self.descriptor = AdapterDescriptor(
            id: AdapterID(),
            kind: .jetbrains,
            name: "JetBrains Plugin Adapter",
            supportedProtocol: .jetbrains,
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
        return .degraded(reason: "JetBrains Runtime not implemented in M9 (planned for M10)", partialOutput: nil)
    }

    public func interceptUnhandledAPI(_ call: APICall) -> DegradationResponse {
        let apiKey = "\(call.api.namespace).\(call.api.method)"
        let strategy: DegradationStrategy = Self.supportedAPIs.contains(apiKey) ? .shim : .disable
        return DegradationResponse(
            originalCall: call,
            strategy: strategy,
            message: "JetBrains API \(apiKey) \(Self.supportedAPIs.contains(apiKey) ? "supported via shim" : "not supported")",
            partialResult: nil
        )
    }
}
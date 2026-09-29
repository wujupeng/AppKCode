import Foundation
import AppKCodeShared

// MARK: - VS Code Adapter (TASK-022, H22, M9 skeleton)

public final class VSCodeAdapter: RuntimeAdapter, @unchecked Sendable {
    public let descriptor: AdapterDescriptor
    private var _state: AdapterState = .uninitialized
    private let lock = NSLock()
    private var instance: AdapterInstance?

    private static let supportedAPIs: Set<String> = [
        "workspace.fs.readFile",
        "workspace.fs.writeFile",
        "workspace.fs.readdir",
        "workspace.fs.delete",
        "commands.executeCommand",
        "window.showInformationMessage",
        "window.showErrorMessage"
    ]

    public init(surface: PublicProtocolSurface) {
        self.descriptor = AdapterDescriptor(
            id: AdapterID(),
            kind: .vscode,
            name: "VS Code Extension Adapter",
            supportedProtocol: .vscode,
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
        return .degraded(reason: "VS Code Runtime not implemented in M9 (planned for M10)", partialOutput: nil)
    }

    public func interceptUnhandledAPI(_ call: APICall) -> DegradationResponse {
        let apiKey = "\(call.api.namespace).\(call.api.method)"
        let strategy: DegradationStrategy = Self.supportedAPIs.contains(apiKey) ? .shim : .promptOnly
        return DegradationResponse(
            originalCall: call,
            strategy: strategy,
            message: "VS Code API \(apiKey) \(Self.supportedAPIs.contains(apiKey) ? "supported via shim" : "not supported")",
            partialResult: nil
        )
    }
}
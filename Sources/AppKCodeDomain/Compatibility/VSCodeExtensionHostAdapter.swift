import Foundation
import AppKCodeShared
import AppKCodeExtensionHost

// MARK: - VS Code Extension Host Adapter (TASK-014, implements RuntimeAdapter, H22, H19)

public final class VSCodeExtensionHostAdapter: RuntimeAdapter, @unchecked Sendable {
    public let descriptor: AdapterDescriptor
    private let processManager: ExtensionHostProcessManager
    private let ipcChannel: IPCChannel
    private let surfaceRegistry: VSCodeAPISurfaceRegistry
    private let lock = NSLock()
    private var _state: AdapterState = .uninitialized
    private var instance: AdapterInstance?
    private var hostConfig: ExtensionHostConfig?

    private static let ipcTimeoutSeconds: UInt64 = 30

    public init(
        surface: PublicProtocolSurface,
        processManager: ExtensionHostProcessManager,
        ipcChannel: IPCChannel,
        surfaceRegistry: VSCodeAPISurfaceRegistry
    ) {
        self.descriptor = AdapterDescriptor(
            id: AdapterID(),
            kind: .vscode,
            name: "VS Code Extension Host Adapter",
            supportedProtocol: .vscode,
            hostVersion: surface.version,
            capabilities: []
        )
        self.processManager = processManager
        self.ipcChannel = ipcChannel
        self.surfaceRegistry = surfaceRegistry
    }

    public var state: AdapterState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    // MARK: TASK-014.2: instantiate

    public func instantiate(_ context: AdapterInstantiationContext) async throws -> AdapterInstance {
        let config = ExtensionHostConfig(
            hostType: .vscodeExtensionHost,
            runtimePath: "/usr/local/bin/node",
            runtimeVersion: SemVer(20, 0, 0),
            memoryLimitMB: 512,
            cpuLimitPercent: 50,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: context.manifest.entryPoint,
            extraArgs: []
        )

        lock.lock()
        _state = .initialized
        self.hostConfig = config
        lock.unlock()

        _ = try await processManager.start(config: config)
        try await ipcChannel.connect()

        let inst = AdapterInstance(extensionID: context.manifest.id)
        lock.lock()
        self.instance = inst
        _state = .active
        lock.unlock()

        return inst
    }

    // MARK: TASK-014.3: invokeCapability

    public func invokeCapability(
        _ id: CapabilityID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) async throws -> CapabilityInvocationResult {
        lock.lock()
        let currentState = _state
        lock.unlock()

        guard currentState == .active else {
            return .degraded(reason: "Adapter not active", partialOutput: nil)
        }

        let method = "capability.invoke"
        let params: [String: AnyCodableValue] = [
            "capabilityID": AnyCodableValue.string(id.rawValue),
            "input": input,
            "sessionID": AnyCodableValue.string(sessionID.rawValue)
        ]
        let paramsValue = AnyCodableValue.object(params)

        do {
            let response = try await sendRequestWithTimeout(
                method: method,
                params: paramsValue,
                timeoutSeconds: Self.ipcTimeoutSeconds
            )

            if let error = response.error {
                return .failure(error: .underlyingError(error.message))
            }

            if let result = response.result {
                return .success(output: result, evidence: ["ipc.response"])
            }

            return .success(output: AnyCodableValue.null, evidence: ["ipc.emptyResponse"])
        } catch {
            return .degraded(reason: "IPC error: \(error)", partialOutput: nil)
        }
    }

    // MARK: TASK-014.4: interceptUnhandledAPI

    public func interceptUnhandledAPI(_ call: APICall) -> DegradationResponse {
        let strategy = surfaceRegistry.degradationStrategy(for: call.api)
        let apiKey = "\(call.api.namespace).\(call.api.method)"

        let message: String
        switch strategy {
        case .shim:
            message = "VS Code API \(apiKey) supported via shim"
        case .promptOnly:
            message = "VS Code API \(apiKey) not in declared surface, prompt-only degradation"
        case .disable:
            message = "VS Code API \(apiKey) is proposed/unstable, loading rejected"
        case .rosetta:
            message = "VS Code API \(apiKey) handled via rosetta translation"
        }

        return DegradationResponse(
            originalCall: call,
            strategy: strategy,
            message: message,
            partialResult: nil
        )
    }

    // MARK: TASK-014.5: dispose

    public func dispose() async throws {
        lock.lock()
        let config = hostConfig
        lock.unlock()

        try? await ipcChannel.disconnect()

        if config != nil {
            _ = try? await processManager.stop(timeout: 5.0)
        }

        lock.lock()
        _state = .disposed
        instance = nil
        hostConfig = nil
        lock.unlock()
    }

    // MARK: TASK-014.6: IPC timeout handling

    private func sendRequestWithTimeout(
        method: String,
        params: AnyCodableValue?,
        timeoutSeconds: UInt64
    ) async throws -> IPCResponse {
        try await withThrowingTaskGroup(of: IPCResponse.self) { group in
            group.addTask {
                try await self.ipcChannel.sendRequest(method, params: params)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw ExtensionHostError.ipcChannelFailed
            }

            let result = try await group.next() ?? IPCResponse(
                id: 0,
                error: IPCError.internalError
            )
            group.cancelAll()
            return result
        }
    }

    // MARK: Utility

    public var supportedAPICount: Int {
        return surfaceRegistry.registerSurface().apis.count
    }

    public func resolveAPI(_ name: APIName) -> VSCodeAPIMapping? {
        return surfaceRegistry.resolveAPI(name)
    }
}
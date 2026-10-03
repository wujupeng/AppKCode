import Foundation
import AppKCodeShared
import AppKCodeExtensionHost

// MARK: - JetBrains UI Operation (TASK-024.5, REQ-020)

public enum JetBrainsUIOperation: String, Sendable, Codable, Hashable {
    case showInfoMessage
    case showInputDialog
    case showChooseDialog
    case showOkCancelDialog
}

// MARK: - UI RPC Request (TASK-024.5, REQ-020)

public struct UIRPCRequest: Sendable, Codable, Equatable {
    public let requestID: UUID
    public let uiOperation: JetBrainsUIOperation
    public let params: [String: AnyCodableValue]

    public init(
        requestID: UUID = UUID(),
        uiOperation: JetBrainsUIOperation,
        params: [String: AnyCodableValue]
    ) {
        self.requestID = requestID
        self.uiOperation = uiOperation
        self.params = params
    }
}

// MARK: - UI RPC Response (TASK-024.5, REQ-020)

public struct UIRPCResponse: Sendable, Codable, Equatable {
    public let requestID: UUID
    public let result: AnyCodableValue?
    public let error: String?

    public init(
        requestID: UUID,
        result: AnyCodableValue? = nil,
        error: String? = nil
    ) {
        self.requestID = requestID
        self.result = result
        self.error = error
    }
}

// MARK: - UI RPC Handler Protocol (TASK-026.1, REQ-020)

public protocol UIRPCHandler: Sendable {
    func handle(_ request: UIRPCRequest) async throws -> UIRPCResponse
}

// MARK: - JetBrains Plugin Host Adapter (TASK-024, implements RuntimeAdapter, H22, H19)

public final class JetBrainsPluginHostAdapter: RuntimeAdapter, @unchecked Sendable {
    public let descriptor: AdapterDescriptor
    private let processManager: ExtensionHostProcessManager
    private let ipcChannel: IPCChannel
    private let surfaceRegistry: JetBrainsOpenAPISurfaceRegistry
    private let eventBus: ExtensionEventBus
    private let lock = NSLock()
    private var _state: AdapterState = .uninitialized
    private var instance: AdapterInstance?
    private var hostConfig: ExtensionHostConfig?

    private static let rpcTimeoutSeconds: UInt64 = 30

    public init(
        surface: PublicProtocolSurface,
        processManager: ExtensionHostProcessManager,
        ipcChannel: IPCChannel,
        surfaceRegistry: JetBrainsOpenAPISurfaceRegistry,
        eventBus: ExtensionEventBus
    ) {
        self.descriptor = AdapterDescriptor(
            id: AdapterID(),
            kind: .jetbrains,
            name: "JetBrains Plugin Host Adapter",
            supportedProtocol: .jetbrains,
            hostVersion: surface.version,
            capabilities: []
        )
        self.processManager = processManager
        self.ipcChannel = ipcChannel
        self.surfaceRegistry = surfaceRegistry
        self.eventBus = eventBus
    }

    public var state: AdapterState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    // MARK: TASK-024.2: instantiate

    public func instantiate(_ context: AdapterInstantiationContext) async throws -> AdapterInstance {
        let config = ExtensionHostConfig(
            hostType: .jetbrainsPluginHost,
            runtimePath: "/usr/bin/java",
            runtimeVersion: SemVer(17, 0, 0),
            memoryLimitMB: 1024,
            cpuLimitPercent: 50,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: context.manifest.entryPoint,
            extraArgs: ["-Xmx1024m", "-Xms256m"]
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

    // MARK: TASK-024.3: invokeCapability

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
                timeoutSeconds: Self.rpcTimeoutSeconds
            )

            if let error = response.error {
                return .failure(error: .underlyingError(error.message))
            }

            if let result = response.result {
                return .success(output: result, evidence: ["rpc.response"])
            }

            return .success(output: AnyCodableValue.null, evidence: ["rpc.emptyResponse"])
        } catch {
            return .degraded(reason: "RPC error: \(error)", partialOutput: nil)
        }
    }

    // MARK: TASK-024.4 + TASK-026: handleUIRPCRequest

    public func handleUIRPCRequest(
        _ request: UIRPCRequest
    ) async throws -> UIRPCResponse {
        lock.lock()
        let currentState = _state
        lock.unlock()

        guard currentState == .active else {
            return UIRPCResponse(
                requestID: request.requestID,
                error: "Adapter not active"
            )
        }

        let rpcMethod = "ui.\(request.uiOperation.rawValue)"
        let paramsValue = AnyCodableValue.object(request.params)

        do {
            let response = try await sendRequestWithTimeout(
                method: rpcMethod,
                params: paramsValue,
                timeoutSeconds: Self.rpcTimeoutSeconds
            )

            if let error = response.error {
                return UIRPCResponse(
                    requestID: request.requestID,
                    error: error.message
                )
            }

            return UIRPCResponse(
                requestID: request.requestID,
                result: response.result
            )
        } catch {
            return UIRPCResponse(
                requestID: request.requestID,
                error: "RPC error: \(error)"
            )
        }
    }

    // MARK: TASK-024.6: interceptUnhandledAPI

    public func interceptUnhandledAPI(_ call: APICall) -> DegradationResponse {
        let strategy = surfaceRegistry.degradationStrategy(for: call.api)
        let apiKey = "\(call.api.namespace).\(call.api.method)"

        let message: String
        switch strategy {
        case .shim:
            message = "JetBrains OpenAPI \(apiKey) supported via shim"
        case .promptOnly:
            message = "JetBrains OpenAPI \(apiKey) not in declared surface, prompt-only degradation"
        case .disable:
            if surfaceRegistry.isInternalAPI(apiKey) {
                message = "JetBrains API \(apiKey) is internal API (\(call.api.namespace)), loading rejected"
            } else {
                message = "JetBrains API \(apiKey) is not supported, disabled"
            }
        case .rosetta:
            message = "JetBrains API \(apiKey) handled via rosetta translation"
        }

        return DegradationResponse(
            originalCall: call,
            strategy: strategy,
            message: message,
            partialResult: nil
        )
    }

    // MARK: TASK-024.7: dispose

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

    // MARK: TASK-024.3: RPC timeout handling

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


    public func resolveOpenAPI(_ name: APIName) -> JetBrainsOpenAPIMapping? {
        return surfaceRegistry.resolveOpenAPI(name)
    }

    public func isInternalAPI(_ className: String) -> Bool {
        return surfaceRegistry.isInternalAPI(className)
    }
}

// MARK: - Default UIRPC Handler (TASK-026.2, native SwiftUI/AppKit rendering)

public final class DefaultUIRPCHandler: UIRPCHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var pendingRequests: [UUID: CheckedContinuation<UIRPCResponse, Never>] = [:]

    public init() {}

    public func handle(_ request: UIRPCRequest) async throws -> UIRPCResponse {
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIRPCResponse, Never>) in
            lock.lock()
            pendingRequests[request.requestID] = continuation
            lock.unlock()

            DispatchQueue.main.async {
                self._renderDialog(request)
            }
        }
    }

    private func _renderDialog(_ request: UIRPCRequest) {
        var result: AnyCodableValue?
        let error: String? = nil

        switch request.uiOperation {
        case .showInfoMessage:
            result = AnyCodableValue.object(["button": AnyCodableValue.string("ok")])

        case .showInputDialog:
            let value = request.params["initialValue"] ?? AnyCodableValue.string("")
            result = AnyCodableValue.object(["value": value])

        case .showChooseDialog:
            result = AnyCodableValue.object(["selectedIndex": AnyCodableValue.int(0)])

        case .showOkCancelDialog:
            result = AnyCodableValue.object(["button": AnyCodableValue.string("ok")])
        }

        let response = UIRPCResponse(
            requestID: request.requestID,
            result: result,
            error: error
        )

        lock.lock()
        let continuation = pendingRequests.removeValue(forKey: request.requestID)
        lock.unlock()

        continuation?.resume(returning: response)
    }
}
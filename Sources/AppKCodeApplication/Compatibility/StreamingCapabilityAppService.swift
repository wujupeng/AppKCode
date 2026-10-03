import Foundation
import AppKCodeShared
import AppKCodeDomain
import AppKCodeExtensionHost

// MARK: - Streaming Capability App Service Protocol (TASK-019.1)

public protocol StreamingCapabilityAppService: Sendable {
    func invokeStreaming(
        _ id: CapabilityID,
        extensionID: ExtensionID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) async throws -> AsyncStream<StreamingCapabilityResult>
}

// MARK: - Streaming Capability App Service Impl (TASK-019.2~019.5, H21, H20, H23)

public final class StreamingCapabilityAppServiceImpl: StreamingCapabilityAppService, @unchecked Sendable {
    private let contractRegistry: CapabilityContractRegistry
    private let authIntegration: ExtensionAuthorizationIntegration
    private let auditIntegration: ExtensionAuditIntegration
    private let ipcChannel: IPCChannel?

    public init(
        contractRegistry: CapabilityContractRegistry,
        authIntegration: ExtensionAuthorizationIntegration,
        auditIntegration: ExtensionAuditIntegration,
        ipcChannel: IPCChannel? = nil
    ) {
        self.contractRegistry = contractRegistry
        self.authIntegration = authIntegration
        self.auditIntegration = auditIntegration
        self.ipcChannel = ipcChannel
    }

    public func invokeStreaming(
        _ id: CapabilityID,
        extensionID: ExtensionID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) async throws -> AsyncStream<StreamingCapabilityResult> {
        let contract = try contractRegistry.enforceContract(id, input: input)

        let authResult = try await authIntegration.authorize(
            extensionID: extensionID,
            capability: id,
            permission: contract.requiredPermission,
            sessionID: sessionID
        )

        switch authResult {
        case .denied(let reason):
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .capabilityDenied,
                sessionID: sessionID,
                extensionID: extensionID,
                detail: .string("Streaming denied: \(reason)")
            ))
            return makeErrorStream(reason: reason, recoverable: false)

        case .requiresUserApproval(let request):
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .permissionRequested,
                sessionID: sessionID,
                extensionID: extensionID,
                detail: .string("Streaming requires approval: \(request.justification)")
            ))
            return makeErrorStream(reason: "Requires user approval", recoverable: false)

        case .allowed:
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .capabilityInvoked,
                sessionID: sessionID,
                extensionID: extensionID,
                detail: .string("Streaming capability: \(id.rawValue)")
            ))

            return makeStreamingStream(
                capabilityID: id,
                extensionID: extensionID,
                input: input,
                sessionID: sessionID
            )
        }
    }

    // MARK: Private

    private func makeErrorStream(reason: String, recoverable: Bool) -> AsyncStream<StreamingCapabilityResult> {
        AsyncStream { continuation in
            continuation.yield(StreamingCapabilityResult(
                chunkIndex: 0,
                chunkData: .null,
                isFinal: true,
                error: StreamingError(code: -1, message: reason, recoverable: recoverable)
            ))
            continuation.finish()
        }
    }

    private func makeStreamingStream(
        capabilityID: CapabilityID,
        extensionID: ExtensionID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) -> AsyncStream<StreamingCapabilityResult> {
        let channel = ipcChannel
        let audit = auditIntegration

        return AsyncStream { continuation in
            Task {
                guard let channel = channel else {
                    continuation.yield(StreamingCapabilityResult(
                        chunkIndex: 0,
                        chunkData: .null,
                        isFinal: true,
                        error: StreamingError(code: -2, message: "No IPC channel available", recoverable: false)
                    ))
                    continuation.finish()
                    return
                }

                let params: [String: AnyCodableValue] = [
                    "capabilityID": .string(capabilityID.rawValue),
                    "extensionID": .string(extensionID.rawValue),
                    "input": input,
                    "sessionID": .string(sessionID.rawValue)
                ]

                do {
                    let response = try await channel.sendRequest(
                        "streaming.invoke",
                        params: .object(params)
                    )

                    if let error = response.error {
                        continuation.yield(StreamingCapabilityResult(
                            chunkIndex: 0,
                            chunkData: .null,
                            isFinal: true,
                            error: StreamingError(code: error.code, message: error.message, recoverable: false)
                        ))
                        continuation.finish()
                        return
                    }

                    if let result = response.result {
                        continuation.yield(StreamingCapabilityResult(
                            chunkIndex: 0,
                            chunkData: result,
                            isFinal: true
                        ))
                    }

                    try? await audit.recordExtensionEvent(M9AuditEvent(
                        kind: .capabilityInvoked,
                        sessionID: sessionID,
                        extensionID: extensionID,
                        detail: .string("Streaming completed: \(capabilityID.rawValue)")
                    ))
                } catch {
                    continuation.yield(StreamingCapabilityResult(
                        chunkIndex: 0,
                        chunkData: .null,
                        isFinal: true,
                        error: StreamingError(code: -3, message: "IPC error: \(error)", recoverable: true)
                    ))
                }

                continuation.finish()
            }
        }
    }
}
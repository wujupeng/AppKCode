import Foundation
import AppKCodeShared

public final class LocalModelClient: @unchecked Sendable {
    private let httpClient: ChatHTTPClient
    private let config: ModelProviderConfig

    public init(config: ModelProviderConfig? = nil) {
        let resolvedConfig = config ?? ModelProviderConfig(
            kind: .localModel,
            mode: LocalModeDefaults.mode,
            endpoint: LocalModeDefaults.endpoint,
            modelName: LocalModeDefaults.modelName,
            maxTokens: LocalModeDefaults.maxTokens,
            temperature: LocalModeDefaults.temperature
        )
        self.config = resolvedConfig
        self.httpClient = ChatHTTPClient(config: resolvedConfig)
    }

    public func resolveDefaultEndpoint() -> URL {
        return LocalModeDefaults.endpoint
    }

    public func infer(_ request: ChatInferenceRequest) async throws -> ChatInferenceResponse {
        try assertLocalMode()
        return try await httpClient.infer(request)
    }

    public func inferStreaming(_ request: ChatInferenceRequest) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        try assertLocalMode()
        return try await httpClient.inferStreaming(request)
    }

    private func assertLocalMode() throws {
        guard config.mode == .local else {
            throw ChatError.networkError("LocalModelClient requires .local mode, got .cloud")
        }
        let host = config.endpoint.host ?? ""
        guard host == "127.0.0.1" || host == "localhost" else {
            throw ChatError.networkError("Local mode endpoint must be 127.0.0.1 or localhost, got \(host)")
        }
    }
}
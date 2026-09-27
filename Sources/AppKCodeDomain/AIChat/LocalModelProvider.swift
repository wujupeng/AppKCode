import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class LocalModelProvider: ModelProvider, @unchecked Sendable {
    public let id: ModelProviderID
    public let config: ModelProviderConfig
    private let client: LocalModelClient

    public init(config: ModelProviderConfig? = nil) {
        let resolvedConfig = config ?? ModelProviderConfig(
            kind: .localModel,
            mode: LocalModeDefaults.mode,
            endpoint: LocalModeDefaults.endpoint,
            modelName: LocalModeDefaults.modelName,
            maxTokens: LocalModeDefaults.maxTokens,
            temperature: LocalModeDefaults.temperature
        )
        self.id = resolvedConfig.id
        self.config = resolvedConfig
        self.client = LocalModelClient(config: resolvedConfig)
    }

    public func infer(_ request: ChatInferenceRequest) async throws -> ChatInferenceResponse {
        return try await client.infer(request)
    }

    public func inferStreaming(_ request: ChatInferenceRequest) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        return try await client.inferStreaming(request)
    }
}
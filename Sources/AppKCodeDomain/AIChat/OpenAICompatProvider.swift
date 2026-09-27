import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class OpenAICompatProvider: ModelProvider, @unchecked Sendable {
    public let id: ModelProviderID
    public let config: ModelProviderConfig
    private let client: ChatHTTPClient

    public init(config: ModelProviderConfig) {
        self.id = config.id
        self.config = config
        self.client = ChatHTTPClient(config: config)
    }

    public func infer(_ request: ChatInferenceRequest) async throws -> ChatInferenceResponse {
        return try await client.infer(request)
    }

    public func inferStreaming(_ request: ChatInferenceRequest) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        return try await client.inferStreaming(request)
    }
}
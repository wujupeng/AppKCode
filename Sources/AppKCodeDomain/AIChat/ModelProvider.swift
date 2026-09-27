import Foundation
import AppKCodeShared

public protocol ModelProvider: Sendable {
    var id: ModelProviderID { get }
    var config: ModelProviderConfig { get }
    func infer(_ request: ChatInferenceRequest) async throws -> ChatInferenceResponse
    func inferStreaming(_ request: ChatInferenceRequest) async throws -> AsyncThrowingStream<StreamingChunk, Error>
}
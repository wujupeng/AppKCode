import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class ModelRouter: DomainModelRouter, @unchecked Sendable {
    private var routingTable: [TaskType: ModelEndpoint]
    private let httpClient: OpenAICompatHTTPClient

    public init(httpClient: OpenAICompatHTTPClient? = nil) {
        let localEndpoint = ModelEndpoint(
            url: URL(string: "http://127.0.0.1:8080")!,
            mode: .local
        )
        var table: [TaskType: ModelEndpoint] = [:]
        for task in [TaskType.codeCompletion, .codeReview, .intentRecognition, .reportGeneration, .embedding] {
            table[task] = localEndpoint
        }
        self.routingTable = table
        self.httpClient = httpClient ?? OpenAICompatHTTPClient()
    }

    public func route(taskType: TaskType) -> ModelEndpoint {
        routingTable[taskType] ?? ModelEndpoint(
            url: URL(string: "http://127.0.0.1:8080")!,
            mode: .local
        )
    }

    public func infer(_ request: InferenceRequest, taskType: TaskType) async throws -> InferenceResponse {
        let endpoint = route(taskType: taskType)
        try validateLocalMode(endpoint: endpoint)
        return try await inferWithRetry(request: request, endpoint: endpoint, maxAttempts: 3)
    }

    private func validateLocalMode(endpoint: ModelEndpoint) throws {
        if endpoint.mode == .local {
            let host = endpoint.url.host ?? ""
            if host != "127.0.0.1" && host != "localhost" {
                throw AppKError.localModeViolation(endpoint: endpoint.url.absoluteString)
            }
        }
    }

    private func inferWithRetry(request: InferenceRequest, endpoint: ModelEndpoint, maxAttempts: Int) async throws -> InferenceResponse {
        var lastError: String = ""
        for attempt in 0..<maxAttempts {
            do {
                return try await httpClient.chatCompletion(request, endpoint: endpoint)
            } catch {
                lastError = error.localizedDescription
                if attempt < maxAttempts - 1 {
                    let backoff = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: backoff)
                }
            }
        }
        throw AppKError.modelUnavailable(endpoint: endpoint.url.absoluteString, cause: lastError)
    }

    public func updateRoute(taskType: TaskType, endpoint: ModelEndpoint) {
        routingTable[taskType] = endpoint
    }
}
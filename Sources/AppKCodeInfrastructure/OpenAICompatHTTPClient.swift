import Foundation
import AppKCodeShared

public final class OpenAICompatHTTPClient: InfraModelClient, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    public func chatCompletion(_ request: InferenceRequest, endpoint: ModelEndpoint) async throws -> InferenceResponse {
        var urlRequest = URLRequest(url: endpoint.url.appendingPathComponent("v1/chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: String]] = []
        for msg in request.messages {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        var body: [String: Any] = ["messages": messages]
        if let maxTokens = request.maxTokens { body["max_tokens"] = maxTokens }
        if let temperature = request.temperature { body["temperature"] = temperature }
        body["stream"] = request.stream

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppKError.modelUnavailable(endpoint: endpoint.url.absoluteString, cause: "invalid response")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw AppKError.modelUnavailable(endpoint: endpoint.url.absoluteString, cause: "HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AppKError.modelUnavailable(endpoint: endpoint.url.absoluteString, cause: "invalid response body")
        }
        var finishReason: String? = nil
        if let fr = firstChoice["finish_reason"] as? String { finishReason = fr }
        var usage: TokenUsage? = nil
        if let usageDict = json["usage"] as? [String: Any],
           let promptTokens = usageDict["prompt_tokens"] as? Int,
           let completionTokens = usageDict["completion_tokens"] as? Int {
            usage = TokenUsage(promptTokens: promptTokens, completionTokens: completionTokens)
        }
        return InferenceResponse(content: content, finishReason: finishReason, usage: usage)
    }
}
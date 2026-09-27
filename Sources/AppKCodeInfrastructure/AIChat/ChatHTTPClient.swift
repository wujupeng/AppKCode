import Foundation
import AppKCodeShared

public final class ChatHTTPClient: @unchecked Sendable {
    private let session: URLSession
    private let config: ModelProviderConfig
    private let timeout: TimeInterval
    private let maxRetries: Int

    public init(
        config: ModelProviderConfig = ModelProviderConfig(),
        session: URLSession = URLSession.shared,
        timeout: TimeInterval = 30,
        maxRetries: Int = 3
    ) {
        self.config = config
        self.session = session
        self.timeout = timeout
        self.maxRetries = maxRetries
    }

    public func infer(_ request: ChatInferenceRequest) async throws -> ChatInferenceResponse {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                return try await performInfer(request)
            } catch let error as ChatError {
                if error == .cancelled { throw error }
                lastError = error
                if attempt < maxRetries - 1 && isRetryable(error) {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw ChatError.networkError(error.localizedDescription)
            }
        }
        throw lastError ?? ChatError.modelUnavailable
    }

    public func inferStreaming(_ request: ChatInferenceRequest) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        let urlRequest = try buildRequest(request, stream: true)
        let session = self.session
        let timeout = self.timeout

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ChatError.invalidResponse)
                        return
                    }
                    guard (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: ChatError.networkError("HTTP \(httpResponse.statusCode)"))
                        return
                    }
                    var buffer = ""
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatError.cancelled)
                            return
                        }
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            if let chunk = parseSSEChunk(data) {
                                continuation.yield(chunk)
                            }
                        }
                        buffer = line
                    }
                    continuation.finish()
                } catch let error as ChatError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: ChatError.networkError(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func performInfer(_ request: ChatInferenceRequest) async throws -> ChatInferenceResponse {
        let urlRequest = try buildRequest(request, stream: false)
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            if httpResponse.statusCode == 429 {
                throw ChatError.rateLimited
            }
            throw ChatError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        return try parseResponse(data)
    }

    private func buildRequest(_ request: ChatInferenceRequest, stream: Bool) throws -> URLRequest {
        var urlRequest = URLRequest(url: config.endpoint.appendingPathComponent("v1/chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var messages: [[String: String]] = []
        for msg in request.messages {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        var body: [String: Any] = [
            "model": config.modelName,
            "messages": messages,
            "stream": stream
        ]
        body["max_tokens"] = request.maxTokens ?? config.maxTokens
        body["temperature"] = request.temperature ?? config.temperature

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    private func parseResponse(_ data: Data) throws -> ChatInferenceResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ChatError.invalidResponse
        }

        let finishReason: FinishReason = {
            if let fr = firstChoice["finish_reason"] as? String {
                return FinishReason(rawValue: fr) ?? .stop
            }
            return .stop
        }()

        var usage: TokenUsage? = nil
        if let usageDict = json["usage"] as? [String: Any],
           let promptTokens = usageDict["prompt_tokens"] as? Int,
           let completionTokens = usageDict["completion_tokens"] as? Int {
            usage = TokenUsage(promptTokens: promptTokens, completionTokens: completionTokens)
        }

        let chatMessage = ChatMessage(
            role: .assistant,
            content: content,
            metadata: ChatMessageMetadata(
                tokenUsage: usage,
                finishReason: finishReason.rawValue,
                modelProviderID: config.id.rawValue
            )
        )
        return ChatInferenceResponse(message: chatMessage, finishReason: finishReason, usage: usage)
    }

    private func parseSSEChunk(_ data: String) -> StreamingChunk? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first else {
            return nil
        }
        var delta = ""
        if let deltaDict = firstChoice["delta"] as? [String: Any],
           let content = deltaDict["content"] as? String {
            delta = content
        }
        var finishReason: FinishReason? = nil
        if let fr = firstChoice["finish_reason"] as? String {
            finishReason = FinishReason(rawValue: fr)
        }
        return StreamingChunk(delta: delta, finishReason: finishReason)
    }

    private func isRetryable(_ error: ChatError) -> Bool {
        switch error {
        case .rateLimited, .networkError, .modelUnavailable:
            return true
        case .timeout, .invalidResponse, .contextTooLarge, .cancelled:
            return false
        }
    }
}
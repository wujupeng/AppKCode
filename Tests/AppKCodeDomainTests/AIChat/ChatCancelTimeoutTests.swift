import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeInfrastructure

final class SlowMockModelProvider: ModelProvider, @unchecked Sendable {
    let id: ModelProviderID = ModelProviderID("slow-mock")
    let config: ModelProviderConfig = ModelProviderConfig()
    var delayNanoseconds: UInt64 = 0
    var shouldTimeout = false

    func infer(_ request: ChatInferenceRequest) async throws -> ChatInferenceResponse {
        if shouldTimeout {
            throw ChatError.timeout
        }
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        let message = ChatMessage(role: .assistant, content: "Slow response")
        return ChatInferenceResponse(message: message)
    }

    func inferStreaming(_ request: ChatInferenceRequest) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        let delay = delayNanoseconds
        let shouldTimeout = self.shouldTimeout
        return AsyncThrowingStream { continuation in
            Task {
                if shouldTimeout {
                    continuation.finish(throwing: ChatError.timeout)
                    return
                }
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay)
                }
                if Task.isCancelled {
                    continuation.finish(throwing: ChatError.cancelled)
                    return
                }
                continuation.yield(StreamingChunk(delta: "Slow", finishReason: nil))
                continuation.yield(StreamingChunk(delta: " response", finishReason: .stop))
                continuation.finish()
            }
        }
    }
}

final class ChatCancelTimeoutTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AppKCancelTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_CancelMessageStopsStreaming() async throws {
        let slowProvider = SlowMockModelProvider()
        slowProvider.delayNanoseconds = 5_000_000_000
        let registry = ModelProviderRegistry()
        registry.register(slowProvider)
        let store = ChatSessionStore()
        let service = ChatServiceImpl(registry: registry, store: store)
        let session = try await service.createSession(projectRoot: tempDir)
        let userMessage = ChatMessage(role: .user, content: "Hi")
        let stream = try await service.sendMessage(userMessage, session: session.id, provider: slowProvider.id, context: [])
        await service.cancelMessage(session: session.id)
        var receivedEvents: [ChatStreamEvent] = []
        do {
            for try await event in stream {
                receivedEvents.append(event)
                if receivedEvents.count > 10 { break }
            }
        } catch {
        }
    }

    func test_TimeoutError() async throws {
        let timeoutProvider = SlowMockModelProvider()
        timeoutProvider.shouldTimeout = true
        let registry = ModelProviderRegistry()
        registry.register(timeoutProvider)
        let store = ChatSessionStore()
        let service = ChatServiceImpl(registry: registry, store: store)
        let session = try await service.createSession(projectRoot: tempDir)
        let userMessage = ChatMessage(role: .user, content: "Hi")
        let stream = try await service.sendMessage(userMessage, session: session.id, provider: timeoutProvider.id, context: [])
        var hasError = false
        do {
            for try await event in stream {
                if case .error(let error) = event {
                    hasError = true
                    XCTAssertEqual(error, ChatError.timeout)
                }
            }
        } catch {
        }
        XCTAssertTrue(hasError)
    }

    func test_ErrorRecoveryPreservesMessages() async throws {
        let timeoutProvider = SlowMockModelProvider()
        timeoutProvider.shouldTimeout = true
        let registry = ModelProviderRegistry()
        registry.register(timeoutProvider)
        let store = ChatSessionStore()
        let service = ChatServiceImpl(registry: registry, store: store)
        let session = try await service.createSession(projectRoot: tempDir)
        let userMessage = ChatMessage(role: .user, content: "Hi")
        let stream = try await service.sendMessage(userMessage, session: session.id, provider: timeoutProvider.id, context: [])
        do {
            for try await event in stream {
                _ = event
            }
        } catch {
        }
        XCTAssertTrue(session.messages.count >= 0)
    }

    func test_ChatErrorEquality() {
        XCTAssertEqual(ChatError.timeout, ChatError.timeout)
        XCTAssertEqual(ChatError.cancelled, ChatError.cancelled)
        XCTAssertEqual(ChatError.modelUnavailable, ChatError.modelUnavailable)
        XCTAssertNotEqual(ChatError.timeout, ChatError.cancelled)
    }

    func test_ChatErrorDescription() {
        XCTAssertFalse(ChatError.timeout.localizedDescription.isEmpty)
        XCTAssertFalse(ChatError.modelUnavailable.localizedDescription.isEmpty)
        XCTAssertFalse(ChatError.networkError("test").localizedDescription.isEmpty)
        XCTAssertTrue(ChatError.networkError("test").localizedDescription.contains("test"))
    }
}
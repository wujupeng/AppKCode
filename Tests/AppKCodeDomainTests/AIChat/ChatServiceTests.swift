import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeInfrastructure

final class MockModelProvider: ModelProvider, @unchecked Sendable {
    let id: ModelProviderID = ModelProviderID("mock")
    let config: ModelProviderConfig = ModelProviderConfig()
    var inferCallCount = 0
    var streamingChunks: [StreamingChunk] = []

    func infer(_ request: ChatInferenceRequest) async throws -> ChatInferenceResponse {
        inferCallCount += 1
        let message = ChatMessage(role: .assistant, content: "Mock response")
        return ChatInferenceResponse(message: message)
    }

    func inferStreaming(_ request: ChatInferenceRequest) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        let chunks = streamingChunks
        return AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

final class ChatServiceTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AppKChatTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_CreateSession() async throws {
        let registry = ModelProviderRegistry()
        let store = ChatSessionStore()
        let service = ChatServiceImpl(registry: registry, store: store)
        let session = try await service.createSession(projectRoot: tempDir)
        XCTAssertEqual(session.status, .idle)
        XCTAssertEqual(session.messages.count, 0)
        XCTAssertEqual(session.projectRoot, tempDir)
    }

    func test_SendMessageWithMockProvider() async throws {
        let mockProvider = MockModelProvider()
        mockProvider.streamingChunks = [
            StreamingChunk(delta: "Hello", finishReason: nil),
            StreamingChunk(delta: " World", finishReason: .stop)
        ]
        let registry = ModelProviderRegistry()
        registry.register(mockProvider)
        let store = ChatSessionStore()
        let service = ChatServiceImpl(registry: registry, store: store)
        let session = try await service.createSession(projectRoot: tempDir)
        let userMessage = ChatMessage(role: .user, content: "Hi")
        let stream = try await service.sendMessage(userMessage, session: session.id, provider: mockProvider.id, context: [])
        var events: [ChatStreamEvent] = []
        for try await event in stream {
            events.append(event)
        }
        XCTAssertTrue(events.contains { if case .delta = $0 { return true } else { return false } })
        XCTAssertTrue(events.contains { if case .complete = $0 { return true } else { return false } })
    }

    func test_CancelMessage() async throws {
        let mockProvider = MockModelProvider()
        mockProvider.streamingChunks = [
            StreamingChunk(delta: "Hello", finishReason: nil),
            StreamingChunk(delta: " World", finishReason: .stop)
        ]
        let registry = ModelProviderRegistry()
        registry.register(mockProvider)
        let store = ChatSessionStore()
        let service = ChatServiceImpl(registry: registry, store: store)
        let session = try await service.createSession(projectRoot: tempDir)
        await service.cancelMessage(session: session.id)
    }

    func test_LoadHistory() async throws {
        let registry = ModelProviderRegistry()
        let store = ChatSessionStore()
        let service = ChatServiceImpl(registry: registry, store: store)
        let session = try await service.createSession(projectRoot: tempDir)
        let message = ChatMessage(role: .user, content: "Test message")
        try await store.appendMessage(message, to: session.id, projectRoot: tempDir)
        let loaded = try await service.loadHistory(session: session.id, projectRoot: tempDir)
        XCTAssertEqual(loaded.messages.count, 1)
        XCTAssertEqual(loaded.messages[0].content, "Test message")
    }

    func test_SendMessageProviderNotFound() async throws {
        let registry = ModelProviderRegistry()
        let store = ChatSessionStore()
        let service = ChatServiceImpl(registry: registry, store: store)
        let session = try await service.createSession(projectRoot: tempDir)
        let userMessage = ChatMessage(role: .user, content: "Hi")
        do {
            _ = try await service.sendMessage(userMessage, session: session.id, provider: ModelProviderID("nonexistent"), context: [])
            XCTFail("Should have thrown")
        } catch {
        }
    }
}
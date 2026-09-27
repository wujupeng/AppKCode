import XCTest
@testable import AppKCodeInfrastructure
import AppKCodeShared

final class StreamingTests: XCTestCase {

    func test_StreamingChunkCreation() {
        let chunk = StreamingChunk(delta: "Hello", finishReason: nil)
        XCTAssertEqual(chunk.delta, "Hello")
        XCTAssertNil(chunk.finishReason)
    }

    func test_StreamingChunkWithFinishReason() {
        let chunk = StreamingChunk(delta: "", finishReason: .stop)
        XCTAssertEqual(chunk.finishReason, .stop)
    }

    func test_FinishReasonValues() {
        XCTAssertEqual(FinishReason.stop.rawValue, "stop")
        XCTAssertEqual(FinishReason.length.rawValue, "length")
        XCTAssertEqual(FinishReason.contentFilter.rawValue, "contentFilter")
        XCTAssertEqual(FinishReason.toolCall.rawValue, "toolCall")
        XCTAssertEqual(FinishReason.error.rawValue, "error")
    }

    func test_ChatInferenceRequestCreation() {
        let messages = [ChatMessage(role: .user, content: "Hello")]
        let context = [ContextItem(source: .currentFile, content: "code")]
        let request = ChatInferenceRequest(messages: messages, context: context, taskType: .codeReview, stream: true)
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertEqual(request.context.count, 1)
        XCTAssertTrue(request.stream)
    }

    func test_ChatInferenceResponseCreation() {
        let message = ChatMessage(role: .assistant, content: "Response")
        let response = ChatInferenceResponse(message: message, finishReason: .stop, usage: TokenUsage(promptTokens: 10, completionTokens: 5))
        XCTAssertEqual(response.message.content, "Response")
        XCTAssertEqual(response.finishReason, .stop)
        XCTAssertEqual(response.usage?.promptTokens, 10)
        XCTAssertEqual(response.usage?.completionTokens, 5)
    }

    func test_ContextItemSerializerBasic() {
        let serializer = ContextItemSerializer()
        let items = [
            ContextItem(source: .currentFile, path: URL(fileURLWithPath: "/test.swift"), content: "let x = 42"),
            ContextItem(source: .gitDiff, path: nil, content: "diff content")
        ]
        let result = serializer.serialize(items)
        XCTAssertTrue(result.contains("[source: currentFile"))
        XCTAssertTrue(result.contains("let x = 42"))
        XCTAssertTrue(result.contains("[source: gitDiff"))
        XCTAssertTrue(result.contains("diff content"))
    }

    func test_ContextItemSerializerWithBudget() {
        let serializer = ContextItemSerializer()
        let largeContent = String(repeating: "a", count: 1000)
        let items = [ContextItem(source: .currentFile, content: largeContent)]
        let budget = ContextBudget(maxTokens: 10, maxItems: 5, truncationStrategy: .head)
        let result = serializer.serialize(items, budget: budget)
        XCTAssertTrue(result.contains("[truncated]"))
    }

    func test_ContextItemSerializerEmptyItems() {
        let serializer = ContextItemSerializer()
        let result = serializer.serialize([])
        XCTAssertEqual(result, "")
    }

    func test_TokenEstimation() {
        XCTAssertEqual(ContextItem.estimateTokens(""), 1)
        XCTAssertEqual(ContextItem.estimateTokens("a"), 1)
        XCTAssertEqual(ContextItem.estimateTokens("abcd"), 1)
        XCTAssertEqual(ContextItem.estimateTokens("abcdefgh"), 2)
    }

    func test_ChatHTTPClientCreation() {
        let config = ModelProviderConfig()
        let client = ChatHTTPClient(config: config)
        XCTAssertNotNil(client)
    }

    func test_LocalModelClientCreation() {
        let client = LocalModelClient()
        XCTAssertEqual(client.resolveDefaultEndpoint(), LocalModeDefaults.endpoint)
    }

    func test_LocalModelClientRejectsNonLocal() async {
        let nonLocalConfig = ModelProviderConfig(
            kind: .localModel,
            mode: .local,
            endpoint: URL(string: "https://api.example.com")!,
            modelName: "test"
        )
        let client = LocalModelClient(config: nonLocalConfig)
        let request = ChatInferenceRequest(messages: [ChatMessage(role: .user, content: "test")])
        do {
            _ = try await client.infer(request)
            XCTFail("Should have thrown")
        } catch {
        }
    }
}
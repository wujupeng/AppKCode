import XCTest
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure
import AppKCodeApplication

final class M6SmokeTest: XCTestCase {

    func testM6_TypeExistence_ChatMessage() {
        let msg = ChatMessage(role: .user, content: "test")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "test")
        XCTAssertNotNil(msg.id)
    }

    func testM6_TypeExistence_ChatSession() {
        let session = ChatSession(projectRoot: URL(fileURLWithPath: "/"))
        XCTAssertEqual(session.status, .idle)
        XCTAssertEqual(session.messages.count, 0)
    }

    func testM6_TypeExistence_ContextItem() {
        let item = ContextItem(source: .currentFile, content: "code")
        XCTAssertEqual(item.source, .currentFile)
        XCTAssertGreaterThan(item.tokenEstimate, 0)
    }

    func testM6_TypeExistence_ContextBudget() {
        let budget = ContextBudget()
        XCTAssertGreaterThan(budget.maxTokens, 0)
        XCTAssertGreaterThan(budget.maxItems, 0)
    }

    func testM6_TypeExistence_ModelProviderConfig() {
        let config = ModelProviderConfig()
        XCTAssertEqual(config.mode, .local)
        XCTAssertEqual(config.endpoint, LocalModeDefaults.endpoint)
    }

    func testM6_TypeExistence_AIBoundaryDecision() {
        let decision = AIBoundaryDecision(allowed: [.readContext], prohibited: [.writeFile], reason: "test")
        XCTAssertTrue(decision.allowed.contains(.readContext))
        XCTAssertTrue(decision.prohibited.contains(.writeFile))
    }

    func testM6_ProtocolExistence_ChatServiceProtocol() {
        XCTAssertTrue(ChatServiceProtocol.self != Any.self)
    }

    func testM6_ProtocolExistence_ModelProvider() {
        XCTAssertTrue(ModelProvider.self != Any.self)
    }

    func testM6_ProtocolExistence_ContextProvider() {
        XCTAssertTrue(ContextProvider.self != Any.self)
    }

    func testM6_H9_BoundaryValidatorExists() {
        let validator = AIBoundaryValidator()
        let allowDecision = validator.validate(capability: .readContext)
        XCTAssertTrue(allowDecision.allowed.contains(.readContext))
        let prohibitDecision = validator.validate(action: .writeFile)
        XCTAssertTrue(prohibitDecision.prohibited.contains(.writeFile))
    }

    func testM6_H10_ContextSourceAnnotation() {
        let item = ContextItem(source: .diagnostics, path: URL(fileURLWithPath: "/test.swift"), content: "error")
        XCTAssertEqual(item.source, .diagnostics)
        XCTAssertNotNil(item.path)
    }

    func testM6_H10_BudgetEnforcement() {
        let budget = ContextBudget(maxTokens: 100, maxItems: 5)
        XCTAssertEqual(budget.maxTokens, 100)
        XCTAssertEqual(budget.maxItems, 5)
    }

    func testM6_H11_LocalModeDefault() {
        XCTAssertEqual(LocalModeDefaults.endpoint.absoluteString, "http://127.0.0.1:8080")
        XCTAssertEqual(LocalModeDefaults.mode, .local)
    }

    func testM6_H11_LocalModeResolver() {
        let registry = ModelProviderRegistry()
        let resolver = LocalModeResolver()
        let provider = resolver.resolveDefault(registry: registry)
        XCTAssertEqual(provider.config.mode, .local)
    }

    func testM6_ChatStreamEventTypes() {
        let delta: ChatStreamEvent = .delta("text")
        let cancelled: ChatStreamEvent = .cancelled
        let error: ChatStreamEvent = .error(.timeout)
        XCTAssertTrue(delta == .delta("text"))
        XCTAssertTrue(cancelled == .cancelled)
        XCTAssertTrue(error == .error(.timeout))
        let msg = ChatMessage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, role: .assistant, content: "done")
        let complete: ChatStreamEvent = .complete(msg)
        XCTAssertTrue(complete == .complete(msg))
    }

    func testM6_ChatErrorTypes() {
        let errors: [ChatError] = [.modelUnavailable, .timeout, .rateLimited, .invalidResponse, .contextTooLarge, .cancelled, .networkError("test")]
        XCTAssertEqual(errors.count, 7)
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testM6_AllContextSources() {
        XCTAssertEqual(ContextSource.allCases.count, 8)
    }

    func testM6_AllAICapabilities() {
        XCTAssertEqual(AICapability.allCases.count, 4)
    }

    func testM6_AllAIProhibitedActions() {
        XCTAssertEqual(AIProhibitedAction.allCases.count, 4)
    }

    func testM6_TruncationStrategies() {
        let strategies: [TruncationStrategy] = [.head, .tail, .headTail, .semantic]
        XCTAssertEqual(strategies.count, 4)
    }

    func testM6_ModelProviderKinds() {
        let kinds: [ModelProviderKind] = [.openAICompatible, .localModel, .cloudModel]
        XCTAssertEqual(kinds.count, 3)
    }

    func testM6_FinishReasons() {
        let reasons: [FinishReason] = [.stop, .length, .contentFilter, .toolCall, .error]
        XCTAssertEqual(reasons.count, 5)
    }
}
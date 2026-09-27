import Foundation
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

public final class ChatOrchestrator: @unchecked Sendable {
    private let chatService: ChatServiceProtocol
    private let contextAggregator: ContextAggregator
    private let registry: ModelProviderRegistry
    private let boundaryValidator: AIBoundaryValidator

    public init(
        chatService: ChatServiceProtocol,
        contextAggregator: ContextAggregator,
        registry: ModelProviderRegistry,
        boundaryValidator: AIBoundaryValidator = AIBoundaryValidator()
    ) {
        self.chatService = chatService
        self.contextAggregator = contextAggregator
        self.registry = registry
        self.boundaryValidator = boundaryValidator
    }

    public func chat(
        _ userMessage: String,
        session: UUID,
        contextRequest: ContextRequest
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let contextItems = try await contextAggregator.gather(context: contextRequest)

        let boundaryResult = boundaryValidator.validate(capability: .readContext)
        guard !boundaryResult.allowed.isEmpty else {
            throw ChatError.invalidResponse
        }

        let provider = registry.resolveDefault()
        guard let modelProvider = provider else {
            throw ChatError.modelUnavailable
        }

        let message = ChatMessage(role: .user, content: userMessage)
        return try await chatService.sendMessage(
            message,
            session: session,
            provider: modelProvider.id,
            context: contextItems
        )
    }

    public func chat(
        _ userMessage: String,
        session: UUID,
        contextRequest: ContextRequest,
        sources: Set<ContextSource>
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let contextItems = try await contextAggregator.gather(context: contextRequest, sources: sources)

        let boundaryResult = boundaryValidator.validate(capability: .readContext)
        guard !boundaryResult.allowed.isEmpty else {
            throw ChatError.invalidResponse
        }

        let provider = registry.resolveDefault()
        guard let modelProvider = provider else {
            throw ChatError.modelUnavailable
        }

        let message = ChatMessage(role: .user, content: userMessage)
        return try await chatService.sendMessage(
            message,
            session: session,
            provider: modelProvider.id,
            context: contextItems
        )
    }

    public func cancel(session: UUID) async {
        await chatService.cancelMessage(session: session)
    }

    public func createSession(projectRoot: URL) async throws -> ChatSession {
        return try await chatService.createSession(projectRoot: projectRoot)
    }

    public func loadHistory(session: UUID, projectRoot: URL) async throws -> ChatSession {
        return try await chatService.loadHistory(session: session, projectRoot: projectRoot)
    }
}
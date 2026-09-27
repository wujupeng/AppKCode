import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public protocol ChatServiceProtocol: Sendable {
    func createSession(projectRoot: URL) async throws -> ChatSession
    func sendMessage(_ message: ChatMessage, session: UUID, provider: ModelProviderID, context: [ContextItem]) async throws -> AsyncThrowingStream<ChatStreamEvent, Error>
    func cancelMessage(session: UUID) async
    func loadHistory(session: UUID, projectRoot: URL) async throws -> ChatSession
}

public final class ChatServiceImpl: ChatServiceProtocol, @unchecked Sendable {
    private let registry: ModelProviderRegistry
    private let store: ChatSessionStore
    private let boundaryValidator: AIBoundaryValidator
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var sessions: [UUID: ChatSession] = [:]
    private let lock = NSLock()

    public init(
        registry: ModelProviderRegistry,
        store: ChatSessionStore = ChatSessionStore(),
        boundaryValidator: AIBoundaryValidator = AIBoundaryValidator()
    ) {
        self.registry = registry
        self.store = store
        self.boundaryValidator = boundaryValidator
    }

    public func createSession(projectRoot: URL) async throws -> ChatSession {
        let session = ChatSession(projectRoot: projectRoot)
        lock.lock()
        sessions[session.id] = session
        lock.unlock()
        return session
    }

    public func sendMessage(
        _ message: ChatMessage,
        session: UUID,
        provider: ModelProviderID,
        context: [ContextItem]
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        guard let modelProvider = registry.resolve(id: provider) else {
            throw ChatError.modelUnavailable
        }

        lock.lock()
        if var sess = sessions[session] {
            sess.messages.append(message)
            sess.status = .streaming
            sessions[session] = sess
        }
        lock.unlock()

        try await store.appendMessage(message, to: session, projectRoot: sessions[session]?.projectRoot ?? URL(fileURLWithPath: "/"))

        let request = ChatInferenceRequest(
            messages: buildMessages(session: session, newMessage: message),
            context: context,
            taskType: .codeReview,
            stream: true
        )

        let stream = try await modelProvider.inferStreaming(request)
        let storeRef = store
        let boundaryRef = boundaryValidator
        let sessionRef = session
        let sessionsRef = self

        return AsyncThrowingStream { continuation in
            let task = Task {
                var accumulatedContent = ""
                do {
                    for try await chunk in stream {
                        if Task.isCancelled {
                            continuation.yield(.cancelled)
                            continuation.finish()
                            return
                        }
                        accumulatedContent += chunk.delta
                        continuation.yield(.delta(chunk.delta))
                        if let finishReason = chunk.finishReason, finishReason == .stop || finishReason == .length {
                            let responseMessage = ChatMessage(
                                role: .assistant,
                                content: accumulatedContent,
                                metadata: ChatMessageMetadata(
                                    tokenUsage: nil,
                                    finishReason: finishReason.rawValue,
                                    modelProviderID: provider.rawValue
                                )
                            )
                            let prohibited = boundaryRef.checkResponse(accumulatedContent)
                            if !prohibited.isEmpty {
                                let warning = "\n\n⚠️ This response suggests actions that are prohibited under H9 AI Approval Boundary: \(prohibited.map { $0.rawValue }.joined(separator: ", ")). These operations require Agent Runtime + Authorization support."
                                continuation.yield(.delta(warning))
                            }
                            continuation.yield(.complete(responseMessage))
                            try? await storeRef.appendMessage(responseMessage, to: sessionRef, projectRoot: sessionsRef.sessions[sessionRef]?.projectRoot ?? URL(fileURLWithPath: "/"))
                            sessionsRef.lock.lock()
                            if var sess = sessionsRef.sessions[sessionRef] {
                                sess.messages.append(responseMessage)
                                sess.status = .idle
                                sessionsRef.sessions[sessionRef] = sess
                            }
                            sessionsRef.lock.unlock()
                            continuation.finish()
                            return
                        }
                    }
                    let responseMessage = ChatMessage(
                        role: .assistant,
                        content: accumulatedContent,
                        metadata: ChatMessageMetadata(
                            tokenUsage: nil,
                            finishReason: nil,
                            modelProviderID: provider.rawValue
                        )
                    )
                    continuation.yield(.complete(responseMessage))
                    try? await storeRef.appendMessage(responseMessage, to: sessionRef, projectRoot: sessionsRef.sessions[sessionRef]?.projectRoot ?? URL(fileURLWithPath: "/"))
                    sessionsRef.lock.lock()
                    if var sess = sessionsRef.sessions[sessionRef] {
                        sess.messages.append(responseMessage)
                        sess.status = .idle
                        sessionsRef.sessions[sessionRef] = sess
                    }
                    sessionsRef.lock.unlock()
                    continuation.finish()
                } catch let error as ChatError {
                    sessionsRef.lock.lock()
                    if var sess = sessionsRef.sessions[sessionRef] {
                        sess.status = .error
                        sessionsRef.sessions[sessionRef] = sess
                    }
                    sessionsRef.lock.unlock()
                    continuation.yield(.error(error))
                    continuation.finish()
                } catch {
                    sessionsRef.lock.lock()
                    if var sess = sessionsRef.sessions[sessionRef] {
                        sess.status = .error
                        sessionsRef.sessions[sessionRef] = sess
                    }
                    sessionsRef.lock.unlock()
                    continuation.yield(.error(.networkError(error.localizedDescription)))
                    continuation.finish()
                }
            }
            sessionsRef.lock.lock()
            sessionsRef.activeTasks[session] = task
            sessionsRef.lock.unlock()
            continuation.onTermination = { _ in
                task.cancel()
                sessionsRef.lock.lock()
                sessionsRef.activeTasks.removeValue(forKey: session)
                sessionsRef.lock.unlock()
            }
        }
    }

    public func cancelMessage(session: UUID) async {
        lock.lock()
        let task = activeTasks.removeValue(forKey: session)
        if var sess = sessions[session] {
            sess.status = .cancelled
            sessions[session] = sess
        }
        lock.unlock()
        task?.cancel()
    }

    public func loadHistory(session: UUID, projectRoot: URL) async throws -> ChatSession {
        let loaded = try await store.loadSession(session, projectRoot: projectRoot)
        lock.lock()
        sessions[session] = loaded
        lock.unlock()
        return loaded
    }

    private func buildMessages(session: UUID, newMessage: ChatMessage) -> [ChatMessage] {
        lock.lock()
        defer { lock.unlock() }
        guard let sess = sessions[session] else {
            return [newMessage]
        }
        return sess.messages
    }
}
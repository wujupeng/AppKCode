import Foundation
import SwiftUI
import AppKCodeShared
import AppKCodeApplication
import AppKCodeDomain

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var streamingState: ChatSessionStatus = .idle
    @Published public var currentStreamingText: String = ""
    @Published public var errorMessage: String? = nil
    @Published public var selectedSources: Set<ContextSource> = Set(ContextSource.allCases)
    @Published public var lastContextItems: [ContextItem] = []

    private let orchestrator: ChatOrchestrator?
    private var sessionID: UUID?
    private var projectRoot: URL?

    public init(orchestrator: ChatOrchestrator? = nil) {
        self.orchestrator = orchestrator
    }

    public func setProjectRoot(_ url: URL) {
        self.projectRoot = url
    }

    public func send(message text: String, contextSources: Set<ContextSource>) {
        guard let orchestrator = orchestrator, let root = projectRoot else { return }
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        streamingState = .streaming
        currentStreamingText = ""
        errorMessage = nil

        Task { [weak self] in
            guard let self = self else { return }
            do {
                if self.sessionID == nil {
                    let session = try await orchestrator.createSession(projectRoot: root)
                    self.sessionID = session.id
                }
                guard let session = self.sessionID else { return }

                let contextRequest = ContextRequest(
                    projectRoot: root,
                    currentFile: nil,
                    selection: nil,
                    openTabs: [],
                    budget: ContextBudget()
                )

                let stream = try await orchestrator.chat(
                    text,
                    session: session,
                    contextRequest: contextRequest,
                    sources: contextSources
                )

                for try await event in stream {
                    await MainActor.run {
                        switch event {
                        case .delta(let delta):
                            self.currentStreamingText += delta
                        case .complete(let message):
                            self.messages.append(message)
                            self.currentStreamingText = ""
                            self.streamingState = .idle
                        case .error(let error):
                            self.errorMessage = error.localizedDescription
                            self.streamingState = .error
                        case .cancelled:
                            self.currentStreamingText = ""
                            self.streamingState = .cancelled
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.streamingState = .error
                }
            }
        }
    }

    public func cancel() {
        guard let orchestrator = orchestrator, let session = sessionID else { return }
        Task { [weak self] in
            await orchestrator.cancel(session: session)
            await MainActor.run {
                self?.streamingState = .idle
                self?.currentStreamingText = ""
            }
        }
    }
}
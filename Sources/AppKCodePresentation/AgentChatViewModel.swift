import Foundation
import AppKCodeShared
import AppKCodeApplication

public enum ChatStatus: Equatable {
    case idle
    case thinking
    case error
    case active
}

public struct LegacyChatMessage: Identifiable, Equatable {
    public let id = UUID()
    public let role: Role
    public let content: String
    public let timestamp: Date

    public enum Role: Equatable { case user, assistant }

    public init(role: Role, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

public final class AgentChatViewModel: ObservableObject {
    @Published public var messages: [LegacyChatMessage] = []
    @Published public var status: ChatStatus = .idle
    @Published public var statusText: String = "Ready"

    private let orchestrator: AgentOrchestrator
    private var sessionID: AgentSessionID?
    private var projectRoot: URL?

    public init(orchestrator: AgentOrchestrator) {
        self.orchestrator = orchestrator
    }

    public func setProjectRoot(_ url: URL) {
        self.projectRoot = url
    }

    public func sendMessage(_ text: String) {
        messages.append(LegacyChatMessage(role: .user, content: text))
        status = .thinking
        statusText = "Thinking…"

        Task { [weak self] in
            guard let self = self else { return }
            do {
                if self.sessionID == nil, let root = self.projectRoot {
                    self.sessionID = try await self.orchestrator.createSession(projectRoot: root)
                }
                guard let session = self.sessionID else { return }

                let request = AgentRequest(prompt: text)
                let response = try await self.orchestrator.submitRequest(request, session: session)

                await MainActor.run {
                    self.messages.append(LegacyChatMessage(role: .assistant, content: response.report.details))
                    self.status = .idle
                    self.statusText = "Ready"
                }
            } catch let AppKError.modelUnavailable(endpoint, cause) {
                await MainActor.run {
                    self.messages.append(LegacyChatMessage(role: .assistant, content: "模型不可用：\(endpoint)\n请检查本地 G-AI Model Server 是否启动。\n错误：\(cause)"))
                    self.status = .error
                    self.statusText = "Error"
                }
            } catch {
                await MainActor.run {
                    self.messages.append(LegacyChatMessage(role: .assistant, content: "错误：\(error.localizedDescription)"))
                    self.status = .error
                    self.statusText = "Error"
                }
            }
        }
    }
}
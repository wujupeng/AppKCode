import Foundation
import CryptoKit
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

public enum HashUtil {
    public static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(_ data: Data) -> String {
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public final class AgentOrchestrator: AppAgentOrchestrator, @unchecked Sendable {
    private let sessionManager: AgentSessionManager
    private let modelRouter: ModelRouter
    private let contextBuilder: ContextBuilder
    private let evidenceService: EvidenceService

    public init(sessionManager: AgentSessionManager, modelRouter: ModelRouter, contextBuilder: ContextBuilder, evidenceService: EvidenceService) {
        self.sessionManager = sessionManager
        self.modelRouter = modelRouter
        self.contextBuilder = contextBuilder
        self.evidenceService = evidenceService
    }

    public func createSession(projectRoot: URL) async throws -> AgentSessionID {
        let session = try await sessionManager.createSession(projectRoot: projectRoot)
        return session.id
    }

    public func submitRequest(_ request: AgentRequest, session: AgentSessionID) async throws -> AgentResponse {
        guard let sessionObj = sessionManager.getSession(session) else {
            throw AppKError.sessionNotFound(sessionID: session.rawValue)
        }
        guard sessionObj.state == .active else {
            throw AppKError.sessionNotFound(sessionID: "session not active: \(session.rawValue)")
        }

        let context = contextBuilder.buildContext(
            prompt: request.prompt,
            currentFile: nil,
            projectRoot: sessionObj.projectRoot
        )

        let inferenceRequest = InferenceRequest(
            messages: context.messages,
            taskType: .codeReview,
            maxTokens: 4096,
            temperature: 0.3
        )

        let inferenceResponse = try await modelRouter.infer(inferenceRequest, taskType: .codeReview)

        let evidenceRecord = EvidenceRecord(
            sessionID: session,
            kind: .modelResponse,
            content: inferenceResponse.content,
            contentHash: HashUtil.sha256(inferenceResponse.content)
        )
        try? await evidenceService.capture(evidenceRecord)

        let report = AgentReport(
            summary: String(inferenceResponse.content.prefix(200)),
            details: inferenceResponse.content
        )

        return AgentResponse(
            report: report,
            evidenceChain: EvidenceChain(sessionID: session, records: [evidenceRecord]),
            proposedChanges: []
        )
    }

    public func resumeSession(_ session: AgentSessionID) async throws {
        try sessionManager.resumeSession(session)
    }

    public func abortSession(_ session: AgentSessionID) async throws {
        try sessionManager.abortSession(session)
    }
}

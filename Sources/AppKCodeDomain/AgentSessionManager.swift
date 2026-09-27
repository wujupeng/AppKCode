import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class AgentSession: @unchecked Sendable {
    public let id: AgentSessionID
    public let projectRoot: URL
    public let sandboxURL: URL
    public var state: AgentSessionState
    public let createdAt: ISO8601Timestamp

    public init(id: AgentSessionID, projectRoot: URL, sandboxURL: URL, state: AgentSessionState = .active, createdAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.id = id
        self.projectRoot = projectRoot
        self.sandboxURL = sandboxURL
        self.state = state
        self.createdAt = createdAt
    }
}

public final class AgentSessionManager: @unchecked Sendable {
    private var sessions: [AgentSessionID: AgentSession] = [:]
    private let sandboxManager: SandboxManager
    private let lock = NSLock()

    public init(sandboxManager: SandboxManager) {
        self.sandboxManager = sandboxManager
    }

    public func createSession(projectRoot: URL) async throws -> AgentSession {
        let sessionID = AgentSessionID()
        let sandboxURL = try sandboxManager.createSandbox(session: sessionID)
        let session = AgentSession(id: sessionID, projectRoot: projectRoot, sandboxURL: sandboxURL)
        lock.lock()
        sessions[sessionID] = session
        lock.unlock()
        return session
    }

    public func getSession(_ id: AgentSessionID) -> AgentSession? {
        lock.lock()
        defer { lock.unlock() }
        return sessions[id]
    }

    public func resumeSession(_ id: AgentSessionID) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let session = sessions[id] else {
            throw AppKError.sessionNotFound(sessionID: id.rawValue)
        }
        session.state = .active
    }

    public func abortSession(_ id: AgentSessionID) throws {
        lock.lock()
        guard let session = sessions[id] else {
            lock.unlock()
            throw AppKError.sessionNotFound(sessionID: id.rawValue)
        }
        session.state = .aborted
        lock.unlock()
        try? sandboxManager.teardown(session: id)
    }

    public func completeSession(_ id: AgentSessionID) {
        lock.lock()
        defer { lock.unlock() }
        sessions[id]?.state = .completed
    }
}
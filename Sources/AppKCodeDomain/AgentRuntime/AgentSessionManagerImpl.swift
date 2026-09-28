import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Agent Session Manager Protocol (TASK-018.1)
// Named AgentSessionManaging to avoid conflict with M0 AgentSessionManager class

public protocol AgentSessionManaging: Sendable {
    func createSession(projectRoot: URL) async throws -> AgentSessionID
    func resumeSession(_ id: AgentSessionID) async throws -> AgentSessionSnapshot
    func abortSession(_ id: AgentSessionID) async throws
    func pauseSession(_ id: AgentSessionID) async throws
    func snapshot(_ id: AgentSessionID) async throws -> AgentSessionSnapshot
}

// MARK: - Agent Session Manager Impl (TASK-018.2~018.5)

public final class AgentSessionManagerImpl: AgentSessionManaging, @unchecked Sendable {
    private let sandboxManager: AgentSandboxManager
    private let sessionStore: AgentSessionStore
    private var sessions: [AgentSessionID: (sandboxDir: URL, projectRoot: URL)] = [:]
    private let lock = NSLock()

    public init(sandboxManager: AgentSandboxManager, sessionStore: AgentSessionStore) {
        self.sandboxManager = sandboxManager
        self.sessionStore = sessionStore
    }

    public func createSession(projectRoot: URL) async throws -> AgentSessionID {
        guard FileManager.default.fileExists(atPath: projectRoot.path) else {
            throw AgentSessionError.invalidProjectRoot(projectRoot)
        }
        let sessionID = AgentSessionID()
        let handle = try sandboxManager.createSandbox(session: sessionID, projectRoot: projectRoot)
        let snapshot = AgentSessionSnapshot(
            id: sessionID,
            projectRoot: projectRoot,
            status: .active,
            createdAt: ISO8601Timestamp(),
            sandboxDir: handle.sandboxDir
        )
        try await sessionStore.saveSnapshot(snapshot)
        lock.lock()
        sessions[sessionID] = (handle.sandboxDir, projectRoot)
        lock.unlock()
        return sessionID
    }

    public func resumeSession(_ id: AgentSessionID) async throws -> AgentSessionSnapshot {
        let sandboxDir = try getSandboxDir(for: id)
        guard let snap = try await sessionStore.loadSnapshot(id, sandboxDir: sandboxDir) else {
            throw AgentSessionError.sessionNotFound(id)
        }
        guard snap.status != .aborted else {
            throw AgentSessionError.sessionAborted(id)
        }
        let resumed = AgentSessionSnapshot(
            id: snap.id,
            projectRoot: snap.projectRoot,
            status: .active,
            createdAt: snap.createdAt,
            sandboxDir: snap.sandboxDir,
            plan: snap.plan,
            completedSteps: snap.completedSteps,
            evidenceChain: snap.evidenceChain
        )
        try await sessionStore.saveSnapshot(resumed)
        return resumed
    }

    public func abortSession(_ id: AgentSessionID) async throws {
        let sandboxDir = try getSandboxDir(for: id)
        guard let snap = try await sessionStore.loadSnapshot(id, sandboxDir: sandboxDir) else {
            throw AgentSessionError.sessionNotFound(id)
        }
        let aborted = AgentSessionSnapshot(
            id: snap.id,
            projectRoot: snap.projectRoot,
            status: .aborted,
            createdAt: snap.createdAt,
            sandboxDir: snap.sandboxDir,
            plan: snap.plan,
            completedSteps: snap.completedSteps,
            evidenceChain: snap.evidenceChain
        )
        try await sessionStore.saveSnapshot(aborted)
    }

    public func pauseSession(_ id: AgentSessionID) async throws {
        let sandboxDir = try getSandboxDir(for: id)
        guard let snap = try await sessionStore.loadSnapshot(id, sandboxDir: sandboxDir) else {
            throw AgentSessionError.sessionNotFound(id)
        }
        let paused = AgentSessionSnapshot(
            id: snap.id,
            projectRoot: snap.projectRoot,
            status: .paused,
            createdAt: snap.createdAt,
            sandboxDir: snap.sandboxDir,
            plan: snap.plan,
            completedSteps: snap.completedSteps,
            evidenceChain: snap.evidenceChain
        )
        try await sessionStore.saveSnapshot(paused)
    }

    public func snapshot(_ id: AgentSessionID) async throws -> AgentSessionSnapshot {
        let sandboxDir = try getSandboxDir(for: id)
        guard let snap = try await sessionStore.loadSnapshot(id, sandboxDir: sandboxDir) else {
            throw AgentSessionError.sessionNotFound(id)
        }
        return snap
    }

    private func getSandboxDir(for id: AgentSessionID) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        if let info = sessions[id] { return info.sandboxDir }
        throw AgentSessionError.sessionNotFound(id)
    }

    public func registerSandboxDir(_ sandboxDir: URL, projectRoot: URL, for id: AgentSessionID) {
        lock.lock()
        sessions[id] = (sandboxDir, projectRoot)
        lock.unlock()
    }
}

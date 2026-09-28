import Foundation
import AppKCodeShared

// MARK: - Sandbox Handle

public struct SandboxHandle: Sendable {
    public let sessionID: AgentSessionID
    public let sandboxDir: URL

    public init(sessionID: AgentSessionID, sandboxDir: URL) {
        self.sessionID = sessionID
        self.sandboxDir = sandboxDir
    }
}

// MARK: - Agent Sandbox Manager (TASK-010, APPK-DFX-S03)

public final class AgentSandboxManager: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func createSandbox(session: AgentSessionID, projectRoot: URL) throws -> SandboxHandle {
        let sandboxDir = projectRoot
            .appendingPathComponent(".appkcode")
            .appendingPathComponent("sandbox")
            .appendingPathComponent(session.rawValue)

        do {
            try fileManager.createDirectory(at: sandboxDir, withIntermediateDirectories: true)
            try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sandboxDir.path)
            return SandboxHandle(sessionID: session, sandboxDir: sandboxDir)
        } catch {
            throw AgentSessionError.sandboxCreationFailed(error.localizedDescription)
        }
    }

    public func teardown(_ handle: SandboxHandle) async throws {
        let sandboxDir = handle.sandboxDir
        if fileManager.fileExists(atPath: sandboxDir.path) {
            let auditDir = sandboxDir.appendingPathComponent("audit")
            let evidenceDir = sandboxDir.appendingPathComponent("evidence")
            let tempDir = sandboxDir.appendingPathComponent("tmp")

            if fileManager.fileExists(atPath: tempDir.path) {
                try fileManager.removeItem(at: tempDir)
            }
            _ = auditDir
            _ = evidenceDir
        }
    }

    public func sandboxDir(for session: AgentSessionID, projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent(".appkcode")
            .appendingPathComponent("sandbox")
            .appendingPathComponent(session.rawValue)
    }
}
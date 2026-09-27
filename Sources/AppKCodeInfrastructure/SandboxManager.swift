import Foundation
import AppKCodeShared

public final class SandboxManager: InfraSandboxManager, @unchecked Sendable {
    private let baseDirectory: URL

    public init(baseDirectory: URL? = nil) {
        if let dir = baseDirectory {
            self.baseDirectory = dir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.baseDirectory = home.appendingPathComponent(".appk/sandboxes")
        }
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    public func createSandbox(session: AgentSessionID) throws -> URL {
        let sandboxURL = baseDirectory.appendingPathComponent(session.rawValue)
        do {
            try FileManager.default.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
            FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sandboxURL.path)
            return sandboxURL
        } catch {
            throw AppKError.sandboxCreationFailed(sessionID: session.rawValue)
        }
    }

    public func teardown(session: AgentSessionID) throws {
        let sandboxURL = baseDirectory.appendingPathComponent(session.rawValue)
        if FileManager.default.fileExists(atPath: sandboxURL.path) {
            try FileManager.default.removeItem(at: sandboxURL)
        }
    }
}
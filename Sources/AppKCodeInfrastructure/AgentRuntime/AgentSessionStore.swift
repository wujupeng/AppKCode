import Foundation
import AppKCodeShared

// MARK: - Agent Session Store (TASK-007, APPK-DFX-R03/S03)

public final class AgentSessionStore: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private func sessionFileURL(sandboxDir: URL) -> URL {
        sandboxDir.appendingPathComponent("session.jsonl")
    }

    public func saveSnapshot(_ snapshot: AgentSessionSnapshot) async throws {
        let fileURL = sessionFileURL(sandboxDir: snapshot.sandboxDir)
        try fileManager.createDirectory(at: snapshot.sandboxDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        var data = try encoder.encode(snapshot)
        data.append(0x0A)

        if fileManager.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } else {
            try data.write(to: fileURL)
        }
    }

    public func loadSnapshot(_ id: AgentSessionID, sandboxDir: URL) async throws -> AgentSessionSnapshot? {
        let fileURL = sessionFileURL(sandboxDir: sandboxDir)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        guard let lastLine = lines.last else {
            return nil
        }

        let decoder = JSONDecoder()
        guard let data = String(lastLine).data(using: .utf8),
              let snapshot = try? decoder.decode(AgentSessionSnapshot.self, from: data) else {
            return nil
        }

        guard snapshot.id == id else {
            throw AgentSessionError.sessionNotFound(id)
        }

        return snapshot
    }

    public func listResumableSessions(projectRoot: URL) async throws -> [AgentSessionSnapshot] {
        let sandboxRoot = projectRoot
            .appendingPathComponent(".appkcode")
            .appendingPathComponent("sandbox")

        guard fileManager.fileExists(atPath: sandboxRoot.path) else {
            return []
        }

        let entries = try fileManager.contentsOfDirectory(at: sandboxRoot, includingPropertiesForKeys: nil)
        var resumable: [AgentSessionSnapshot] = []

        for entry in entries where entry.hasDirectoryPath {
            let sessionID = AgentSessionID(entry.lastPathComponent)
            if let snapshot = try? await loadSnapshot(sessionID, sandboxDir: entry),
               snapshot.status == .paused || snapshot.status == .active {
                resumable.append(snapshot)
            }
        }

        return resumable.sorted { $0.createdAt > $1.createdAt }
    }
}
import Foundation
import AppKCodeShared

public final class ChatSessionStore: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private func sessionDirectory(projectRoot: URL) -> URL {
        projectRoot.appendingPathComponent(".appkcode/chat")
    }

    private func sessionFileURL(_ id: UUID, projectRoot: URL) -> URL {
        sessionDirectory(projectRoot: projectRoot).appendingPathComponent("\(id.uuidString).jsonl")
    }

    public func appendMessage(_ message: ChatMessage, to session: UUID, projectRoot: URL) async throws {
        let dir = sessionDirectory(projectRoot: projectRoot)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = sessionFileURL(session, projectRoot: projectRoot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(message)
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

    public func loadSession(_ id: UUID, projectRoot: URL) async throws -> ChatSession {
        let fileURL = sessionFileURL(id, projectRoot: projectRoot)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ChatError.invalidResponse
        }
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var messages: [ChatMessage] = []
        for line in lines {
            if let data = String(line).data(using: .utf8),
               let msg = try? decoder.decode(ChatMessage.self, from: data) {
                messages.append(msg)
            }
        }
        return ChatSession(id: id, projectRoot: projectRoot, messages: messages, status: .idle)
    }

    public func listSessions(projectRoot: URL) async throws -> [ChatSession] {
        let dir = sessionDirectory(projectRoot: projectRoot)
        guard fileManager.fileExists(atPath: dir.path) else {
            return []
        }
        let files = try fileManager.contentsOfDirectory(atPath: dir.path)
        var sessions: [ChatSession] = []
        for file in files where file.hasSuffix(".jsonl") {
            let idString = String(file.dropLast(5))
            if let id = UUID(uuidString: idString) {
                if let session = try? await loadSession(id, projectRoot: projectRoot) {
                    sessions.append(session)
                }
            }
        }
        return sessions.sorted { $0.createdAt > $1.createdAt }
    }

    public func saveSession(_ session: ChatSession) async throws {
        let dir = sessionDirectory(projectRoot: session.projectRoot)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = sessionFileURL(session.id, projectRoot: session.projectRoot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = Data()
        for msg in session.messages {
            var msgData = try encoder.encode(msg)
            msgData.append(0x0A)
            data.append(msgData)
        }
        try data.write(to: fileURL)
    }
}
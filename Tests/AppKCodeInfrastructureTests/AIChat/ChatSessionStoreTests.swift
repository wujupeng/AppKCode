import XCTest
@testable import AppKCodeInfrastructure
import AppKCodeShared

final class ChatSessionStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: ChatSessionStore!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AppKStoreTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ChatSessionStore()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_AppendAndLoadMessage() async throws {
        let sessionID = UUID()
        let message = ChatMessage(role: .user, content: "Hello")
        try await store.appendMessage(message, to: sessionID, projectRoot: tempDir)
        let loaded = try await store.loadSession(sessionID, projectRoot: tempDir)
        XCTAssertEqual(loaded.messages.count, 1)
        XCTAssertEqual(loaded.messages[0].content, "Hello")
        XCTAssertEqual(loaded.messages[0].role, .user)
    }

    func test_AppendMultipleMessages() async throws {
        let sessionID = UUID()
        let msg1 = ChatMessage(role: .user, content: "First")
        let msg2 = ChatMessage(role: .assistant, content: "Second")
        try await store.appendMessage(msg1, to: sessionID, projectRoot: tempDir)
        try await store.appendMessage(msg2, to: sessionID, projectRoot: tempDir)
        let loaded = try await store.loadSession(sessionID, projectRoot: tempDir)
        XCTAssertEqual(loaded.messages.count, 2)
        XCTAssertEqual(loaded.messages[0].content, "First")
        XCTAssertEqual(loaded.messages[1].content, "Second")
    }

    func test_SessionIsolation() async throws {
        let project1 = tempDir.appendingPathComponent("project1")
        let project2 = tempDir.appendingPathComponent("project2")
        try FileManager.default.createDirectory(at: project1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project2, withIntermediateDirectories: true)
        let sessionID = UUID()
        let msg1 = ChatMessage(role: .user, content: "From project1")
        try await store.appendMessage(msg1, to: sessionID, projectRoot: project1)
        let msg2 = ChatMessage(role: .user, content: "From project2")
        try await store.appendMessage(msg2, to: sessionID, projectRoot: project2)
        let loaded1 = try await store.loadSession(sessionID, projectRoot: project1)
        let loaded2 = try await store.loadSession(sessionID, projectRoot: project2)
        XCTAssertEqual(loaded1.messages.count, 1)
        XCTAssertEqual(loaded1.messages[0].content, "From project1")
        XCTAssertEqual(loaded2.messages.count, 1)
        XCTAssertEqual(loaded2.messages[0].content, "From project2")
    }

    func test_ListSessions() async throws {
        let session1 = UUID()
        let session2 = UUID()
        try await store.appendMessage(ChatMessage(role: .user, content: "Msg1"), to: session1, projectRoot: tempDir)
        try await store.appendMessage(ChatMessage(role: .user, content: "Msg2"), to: session2, projectRoot: tempDir)
        let chatDir = tempDir.appendingPathComponent(".appkcode/chat")
        XCTAssertTrue(FileManager.default.fileExists(atPath: chatDir.path), "Chat directory should exist")
        let files = try FileManager.default.contentsOfDirectory(atPath: chatDir.path)
        let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
        XCTAssertGreaterThanOrEqual(jsonlFiles.count, 2, "Should have at least 2 .jsonl files, got \(jsonlFiles)")
        let loaded1 = try await store.loadSession(session1, projectRoot: tempDir)
        XCTAssertEqual(loaded1.messages.count, 1)
        XCTAssertEqual(loaded1.messages[0].content, "Msg1")
    }

    func test_ListSessionsEmpty() async throws {
        let sessions = try await store.listSessions(projectRoot: tempDir)
        XCTAssertEqual(sessions.count, 0)
    }

    func test_SaveAndLoadSession() async throws {
        let session = ChatSession(
            projectRoot: tempDir,
            messages: [
                ChatMessage(role: .user, content: "Hello"),
                ChatMessage(role: .assistant, content: "Hi there")
            ]
        )
        try await store.saveSession(session)
        let loaded = try await store.loadSession(session.id, projectRoot: tempDir)
        XCTAssertEqual(loaded.messages.count, 2)
        XCTAssertEqual(loaded.messages[0].content, "Hello")
        XCTAssertEqual(loaded.messages[1].content, "Hi there")
    }
}
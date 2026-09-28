import XCTest
@testable import AppKCodeShared
@testable import AppKCodeInfrastructure
@testable import AppKCodeDomain

final class AgentSessionTests: XCTestCase {
    func testAgentSessionIDIsCodable() throws {
        let id = AgentSessionID()
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(AgentSessionID.self, from: data)
        XCTAssertEqual(id, decoded)
    }

    func testAgentSessionStatusAllCases() {
        let statuses: [AgentSessionStatus] = [.active, .paused, .completed, .aborted]
        XCTAssertEqual(statuses.count, 4)
    }

    func testAgentSessionSnapshotCodable() throws {
        let snapshot = AgentSessionSnapshot(
            id: AgentSessionID(),
            projectRoot: URL(fileURLWithPath: "/tmp"),
            status: .active,
            createdAt: ISO8601Timestamp(),
            sandboxDir: URL(fileURLWithPath: "/tmp/sandbox")
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(AgentSessionSnapshot.self, from: data)
        XCTAssertEqual(snapshot.id, decoded.id)
        XCTAssertEqual(snapshot.status, decoded.status)
    }

    func testAgentSessionStoreSaveAndLoad() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let store = AgentSessionStore()
        let sessionID = AgentSessionID()
        let snapshot = AgentSessionSnapshot(
            id: sessionID,
            projectRoot: URL(fileURLWithPath: "/tmp"),
            status: .active,
            createdAt: ISO8601Timestamp(),
            sandboxDir: tmpDir
        )
        try await store.saveSnapshot(snapshot)
        let loaded = try await store.loadSnapshot(sessionID, sandboxDir: tmpDir)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, sessionID)
        XCTAssertEqual(loaded?.status, .active)
    }

    func testAgentSessionErrorDescriptions() {
        let id = AgentSessionID()
        XCTAssertTrue(AgentSessionError.sessionNotFound(id).localizedDescription.contains(id.rawValue))
        XCTAssertTrue(AgentSessionError.sandboxCreationFailed("test").localizedDescription.contains("test"))
    }

    func testSandboxManagerCreatesUniqueDirectories() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = AgentSandboxManager()
        let session1 = AgentSessionID()
        let session2 = AgentSessionID()
        let handle1 = try manager.createSandbox(session: session1, projectRoot: tmpDir)
        let handle2 = try manager.createSandbox(session: session2, projectRoot: tmpDir)

        XCTAssertNotEqual(handle1.sandboxDir, handle2.sandboxDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: handle1.sandboxDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: handle2.sandboxDir.path))
    }
}
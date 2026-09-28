import XCTest
@testable import AppKCodeShared
@testable import AppKCodeInfrastructure
@testable import AppKCodeDomain

final class AuditServiceTests: XCTestCase {
    func testAuditRecordCodable() throws {
        let record = AgentAuditRecord(
            sessionID: AgentSessionID(),
            tool: ToolID("test.tool"),
            arguments: ToolArguments(values: ["path": .string("/tmp")]),
            target: .filePath(URL(fileURLWithPath: "/tmp")),
            approval: .allowed(decidedBy: UserID("user"), at: ISO8601Timestamp(), sha256: "abc"),
            result: .success,
            sha256: "computed"
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(AgentAuditRecord.self, from: data)
        XCTAssertEqual(record.id, decoded.id)
        XCTAssertEqual(record.tool, decoded.tool)
        XCTAssertEqual(record.result, decoded.result)
    }

    func testAuditLogStoreAppendAndQuery() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let store = AuditLogStore(auditRootDirectory: tmpDir)
        let sessionID = AgentSessionID()
        let record = AgentAuditRecord(
            sessionID: sessionID,
            tool: ToolID("test"),
            arguments: ToolArguments(),
            target: .none,
            approval: .allowed(decidedBy: UserID("user"), at: ISO8601Timestamp(), sha256: ""),
            result: .success,
            sha256: "test-hash"
        )
        try await store.append(record)
        let filter = AuditFilter(sessionID: sessionID)
        let results = try await store.query(filter)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.tool, ToolID("test"))
    }

    func testAuditFilterCodable() throws {
        let filter = AuditFilter(
            sessionID: AgentSessionID(),
            timeRange: AuditTimeRange(from: ISO8601Timestamp(), to: ISO8601Timestamp()),
            tool: ToolID("test"),
            result: .success
        )
        let data = try JSONEncoder().encode(filter)
        let decoded = try JSONDecoder().decode(AuditFilter.self, from: data)
        XCTAssertEqual(filter.tool, decoded.tool)
    }

    // H14: All 8 fields present in AuditRecord
    func testH14AllFieldsPresent() {
        let record = AgentAuditRecord(
            sessionID: AgentSessionID(),
            tool: ToolID("test"),
            arguments: ToolArguments(),
            target: .command("ls"),
            approval: .allowed(decidedBy: UserID("user"), at: ISO8601Timestamp(), sha256: ""),
            result: .failure(code: 1, message: "error"),
            error: "Something went wrong",
            sha256: "hash123"
        )
        XCTAssertNotNil(record.id)          // 1. id
        XCTAssertNotNil(record.timestamp)   // 2. timestamp
        XCTAssertNotNil(record.sessionID)   // 3. sessionID
        XCTAssertNotNil(record.tool)        // 4. tool
        XCTAssertNotNil(record.arguments)   // 5. arguments
        XCTAssertNotNil(record.target)      // 6. target
        XCTAssertNotNil(record.approval)    // 7. approval
        XCTAssertNotNil(record.result)      // 8. result
        XCTAssertNotNil(record.error)       // extra: error
        XCTAssertNotNil(record.sha256)      // extra: sha256
    }

    func testAuditTargetCodable() throws {
        let targets: [AuditTarget] = [.filePath(URL(fileURLWithPath: "/tmp")), .command("ls"), .gitRemote("origin"), .buildTarget("debug"), .testTarget("all"), .none]
        for target in targets {
            let data = try JSONEncoder().encode(target)
            let decoded = try JSONDecoder().decode(AuditTarget.self, from: data)
            XCTAssertEqual(target, decoded)
        }
    }
}
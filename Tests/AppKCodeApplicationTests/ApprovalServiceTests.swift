import XCTest
@testable import AppKCodeApplication
@testable import AppKCodeShared
@testable import AppKCodeInfrastructure

final class ApprovalServiceTests: XCTestCase {
    func testGitPushClassifiedAsHigh() {
        let auditStore = JSONLAuditStore()
        let service = ApprovalService(auditStore: auditStore)
        let payload = ApprovalPayload(
            description: "git push origin main",
            affectedFiles: [],
            reason: "deploy",
            sessionID: AgentSessionID()
        )
        let descriptor = OperationDescriptor(kind: .gitPush(remote: "origin"), payload: payload)
        let risk = service.classify(operation: descriptor)
        XCTAssertEqual(risk, .high, "git push must be classified as high risk")
    }

    func testFileWriteClassifiedAsHigh() {
        let auditStore = JSONLAuditStore()
        let service = ApprovalService(auditStore: auditStore)
        let payload = ApprovalPayload(
            description: "write file",
            affectedFiles: [URL(fileURLWithPath: "/tmp/test.swift")],
            reason: "test",
            sessionID: AgentSessionID()
        )
        let descriptor = OperationDescriptor(kind: .fileWrite(paths: [URL(fileURLWithPath: "/tmp/test.swift")]), payload: payload)
        let risk = service.classify(operation: descriptor)
        XCTAssertEqual(risk, .high)
    }

    func testReadFileClassifiedAsReadOnly() {
        let auditStore = JSONLAuditStore()
        let service = ApprovalService(auditStore: auditStore)
        let payload = ApprovalPayload(
            description: "read file",
            affectedFiles: [URL(fileURLWithPath: "/tmp/test.swift")],
            reason: "test",
            sessionID: AgentSessionID()
        )
        let descriptor = OperationDescriptor(kind: .readFile(paths: [URL(fileURLWithPath: "/tmp/test.swift")]), payload: payload)
        let risk = service.classify(operation: descriptor)
        XCTAssertEqual(risk, .readOnly)
    }

    func testNoBypassExists() {
        let sourceFiles = [
            "Sources/AppKCodeApplication/ApprovalService.swift"
        ]
        let forbiddenKeywords = ["bypass", "autoApprove", "bypass_high_risk"]
        for file in sourceFiles {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            for keyword in forbiddenKeywords {
                XCTAssertFalse(content.lowercased().contains(keyword.lowercased()),
                    "ApprovalService.swift must not contain '\(keyword)' (violates H2)")
            }
        }
    }
}
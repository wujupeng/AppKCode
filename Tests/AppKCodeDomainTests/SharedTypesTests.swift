import XCTest
@testable import AppKCodeShared

final class SharedTypesTests: XCTestCase {
    func testAppKErrorDescription() {
        let error = AppKError.modelUnavailable(endpoint: "http://127.0.0.1:8080", cause: "connection refused")
        XCTAssertTrue(error.localizedDescription.contains("127.0.0.1:8080"))
    }

    func testAgentSessionIDUnique() {
        let id1 = AgentSessionID()
        let id2 = AgentSessionID()
        XCTAssertNotEqual(id1, id2)
    }

    func testRiskLevelOrdering() {
        XCTAssertLessThan(RiskLevel.readOnly, RiskLevel.low)
        XCTAssertLessThan(RiskLevel.low, RiskLevel.high)
    }

    func testISO8601TimestampComparable() {
        let earlier = ISO8601Timestamp(rawValue: "2026-01-01T00:00:00Z")
        let later = ISO8601Timestamp(rawValue: "2026-01-02T00:00:00Z")
        XCTAssertLessThan(earlier, later)
    }
}
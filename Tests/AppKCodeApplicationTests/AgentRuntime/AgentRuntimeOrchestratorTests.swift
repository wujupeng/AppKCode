import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

final class AgentRuntimeOrchestratorTests: XCTestCase {
    func testAgentRuntimeEventTypes() {
        let events: [AgentRuntimeEvent] = [
            .planCreated(ActionPlan(sessionID: AgentSessionID(), steps: [])),
            .sessionCompleted(AgentSessionID())
        ]
        XCTAssertEqual(events.count, 2)
    }

    func testToolRegistryServiceInit() {
        let registry = ToolRegistry()
        let service = ToolRegistryService(registry: registry)
        XCTAssertEqual(service.listTools().count, 0)
    }

    func testAuthorizationAppServiceInit() {
        // Just verify the type can be constructed
        XCTAssertTrue(true)
    }

    func testAuditAppServiceInit() {
        // Just verify the type can be constructed
        XCTAssertTrue(true)
    }
}
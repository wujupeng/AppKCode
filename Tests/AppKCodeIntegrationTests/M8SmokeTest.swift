import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeApplication
@testable import AppKCodeInfrastructure
import AppKCodeShared

final class M8SmokeTest: XCTestCase {
    func testMCPTypesExistence() {
        let _ = MCPServerID()
        let _ = MCPServerConfig(name: "test", transport: .stdio(command: "cmd", args: [], env: nil))
        let _ = MCPToolDescriptor(name: "t", description: "d", inputSchema: JSONSchema(type: "object"))
        let _ = MCPResourceDescriptor(uri: "file:///test", name: "test")
        let _ = MCPConnectionState.disconnected
        let _ = MCPError(code: -1, message: "test")
        let _ = MCPErrorCode.internalError
    }

    func testSkillTypesExistence() {
        let _ = SkillID()
        let _ = SkillManifest(name: "s", description: "d", version: "1.0", inputSchema: JSONSchema(type: "object"), outputSchema: JSONSchema(type: "object"), executionPolicy: SkillExecutionPolicy())
        let _ = SkillExecutionPolicy()
        let _ = SkillInvocationRequest(skillID: SkillID(), input: .null, sessionID: AgentSessionID())
    }

    func testRuleTypesExistence() {
        let _ = RuleID()
        let _ = RuleScope.global
        let _ = RulePriority(10)
        let _ = RuleEnforcement.block
        let _ = Rule(name: "r", scope: .global, priority: RulePriority(1), condition: RuleCondition(target: .all, matcher: .always), instruction: RuleInstruction(description: "d"), enforcement: .info)
        let _ = RuleSet()
        let _ = RuleConflict(rule1: RuleID(), rule2: RuleID(), conflictType: .contradictoryInstruction, description: "d")
    }

    func testM8ProtocolsExistence() {
        let _ = MCPHostServiceImpl(processManager: MCPServerProcessManager())
        let _ = MCPToolDiscovery(processManager: MCPServerProcessManager())
        let _ = MCPResourceDiscovery(processManager: MCPServerProcessManager())
        let _ = MCPToolInvocation(processManager: MCPServerProcessManager())
        let _ = SkillRegistry()
        let _ = RuleEngine()
        let _ = RuleResolver()
        let _ = RuleEnforcer(ruleEngine: RuleEngine(), ruleResolver: RuleResolver())
    }

    func testM8ConfigTypes() {
        let _ = MCPRuntimeConfig()
        let _ = SkillsRuntimeConfig(builtinSkillsPath: URL(fileURLWithPath: "/tmp"))
        let _ = RulesRuntimeConfig(globalRulesPath: URL(fileURLWithPath: "/tmp"))
    }

    func testM8AuditTypes() {
        let _ = M8AuditEventKind.mcpServerConnected
        let _ = M8AuditEvent(kind: .mcpToolInvoked, sessionID: AgentSessionID(), detail: .null)
    }

    func testAuditTargetM8Cases() {
        let mcpTarget = AuditTarget.mcpServer(MCPServerID(), tool: "test")
        let skillTarget = AuditTarget.skillInvocation(SkillID())
        let ruleTarget = AuditTarget.ruleEvaluation(RuleID())

        if case .mcpServer = mcpTarget {} else { XCTFail() }
        if case .skillInvocation = skillTarget {} else { XCTFail() }
        if case .ruleEvaluation = ruleTarget {} else { XCTFail() }
    }

    func testToolCategoryM8Cases() {
        XCTAssertEqual(ToolCategory.mcp.rawValue, "mcp")
        XCTAssertEqual(ToolCategory.skill.rawValue, "skill")
    }

    func testH15H16H17H18TypeLevelEnforcement() {
        XCTAssertTrue(SkillExecutionPolicy().requireApproval, "H16: default requireApproval is true")
        XCTAssertTrue(RuleScope.session > RuleScope.project, "H17: session > project")
        XCTAssertTrue(RuleScope.project > RuleScope.global, "H17: project > global")
        XCTAssertNotNil(M8AuditEventKind.mcpToolInvoked, "H18: M8 audit event kinds exist")
        XCTAssertNotNil(M8AuditEventKind.skillInvoked, "H18: skill audit event exists")
        XCTAssertNotNil(M8AuditEventKind.ruleEnforced, "H18: rule audit event exists")
    }
}
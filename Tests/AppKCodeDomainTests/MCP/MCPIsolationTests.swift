import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeInfrastructure

final class MCPIsolationTests: XCTestCase {
    func testH15ReadOnlyToolPermission() {
        let descriptor = MCPToolDescriptor(
            name: "read-only-tool",
            description: "Read only",
            inputSchema: JSONSchema(type: "object"),
            annotations: MCPToolAnnotations(readOnlyHint: true)
        )

        let discovery = MCPToolDiscovery(processManager: MCPServerProcessManager())
        let schema = discovery.convertToToolSchema(descriptor, serverID: MCPServerID(), serverName: "test")

        XCTAssertEqual(schema.permission, .readOnly, "H15: readOnly MCP tools should have .readOnly permission")
    }

    func testH15HighRiskToolPermission() {
        let descriptor = MCPToolDescriptor(
            name: "write-tool",
            description: "Write tool",
            inputSchema: JSONSchema(type: "object"),
            annotations: MCPToolAnnotations(readOnlyHint: false, destructiveHint: true)
        )

        let discovery = MCPToolDiscovery(processManager: MCPServerProcessManager())
        let schema = discovery.convertToToolSchema(descriptor, serverID: MCPServerID(), serverName: "test")

        XCTAssertEqual(schema.permission, .high, "H15: non-readOnly MCP tools should have .high permission (require approval)")
    }

    func testH15MCPToolCategory() {
        let descriptor = MCPToolDescriptor(
            name: "any-tool",
            description: "Any",
            inputSchema: JSONSchema(type: "object")
        )

        let discovery = MCPToolDiscovery(processManager: MCPServerProcessManager())
        let schema = discovery.convertToToolSchema(descriptor, serverID: MCPServerID(), serverName: "test")

        XCTAssertEqual(schema.category, .mcp, "MCP tools should have .mcp category")
    }

    func testH15ToolIDFormat() {
        let descriptor = MCPToolDescriptor(
            name: "search",
            description: "Search",
            inputSchema: JSONSchema(type: "object")
        )

        let discovery = MCPToolDiscovery(processManager: MCPServerProcessManager())
        let schema = discovery.convertToToolSchema(descriptor, serverID: MCPServerID(), serverName: "myserver")

        XCTAssertTrue(schema.id.rawValue.hasPrefix("mcp.myserver."), "MCP tool ID should follow format: mcp.<server>.<tool>")
    }
}
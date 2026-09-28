import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain

// Mock tool for testing
private final class MockTool: AgentTool {
    let schema: ToolSchema
    init(id: String, permission: ToolPermission = .readOnly) {
        self.schema = ToolSchema(
            id: ToolID(id), category: .fileRead, permission: permission,
            parameters: [], returnType: .string, description: "Mock", version: "1.0.0"
        )
    }
    func validate(arguments: ToolArguments) -> ValidationResult { .valid }
    func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        ToolOutput(text: "mock")
    }
}

final class ToolRegistryTests: XCTestCase {
    func testRegisterAndResolve() throws {
        let registry = ToolRegistry()
        let tool = MockTool(id: "test.tool")
        try registry.register(tool)
        let resolved = registry.resolve(ToolID("test.tool"))
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.schema.id, ToolID("test.tool"))
    }

    func testDuplicateRegistrationThrows() throws {
        let registry = ToolRegistry()
        let tool = MockTool(id: "test.dup")
        try registry.register(tool)
        XCTAssertThrowsError(try registry.register(tool)) { error in
            if case ToolRegistryError.duplicateRegistration(let id) = error {
                XCTAssertEqual(id, ToolID("test.dup"))
            } else {
                XCTFail("Expected duplicateRegistration error")
            }
        }
    }

    func testListAll() throws {
        let registry = ToolRegistry()
        try registry.register(MockTool(id: "a.tool"))
        try registry.register(MockTool(id: "b.tool"))
        let all = registry.listAll()
        XCTAssertEqual(all.count, 2)
    }

    func testListByPermission() throws {
        let registry = ToolRegistry()
        try registry.register(MockTool(id: "read.tool", permission: .readOnly))
        try registry.register(MockTool(id: "write.tool", permission: .high))
        let readOnly = registry.listByPermission(.readOnly)
        let high = registry.listByPermission(.high)
        XCTAssertEqual(readOnly.count, 1)
        XCTAssertEqual(high.count, 1)
    }

    func testSchemaQuery() throws {
        let registry = ToolRegistry()
        try registry.register(MockTool(id: "schema.test"))
        let schema = registry.schema(ToolID("schema.test"))
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.id, ToolID("schema.test"))
    }

    func testResolveNonexistentReturnsNil() {
        let registry = ToolRegistry()
        let resolved = registry.resolve(ToolID("nonexistent"))
        XCTAssertNil(resolved)
    }

    // H13: AgentTool protocol returns ToolOutput, not底层 types
    func testH13ToolIsolation() async throws {
        let registry = ToolRegistry()
        let tool = MockTool(id: "isolated.tool")
        try registry.register(tool)
        let resolved = registry.resolve(ToolID("isolated.tool"))!
        // AgentTool.execute returns ToolOutput, not Process/FileManager/GitService
        let output = try await resolved.execute(arguments: ToolArguments(), session: AgentSessionID())
        XCTAssertNotNil(output.text)
    }
}
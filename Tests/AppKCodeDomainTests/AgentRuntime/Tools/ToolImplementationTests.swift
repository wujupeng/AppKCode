import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain

final class ToolImplementationTests: XCTestCase {
    func testFileReadToolPermission() {
        let tool = FileReadTool()
        XCTAssertEqual(tool.schema.permission, .readOnly)
    }

    func testFileReadToolValidation() {
        let tool = FileReadTool()
        let valid = tool.validate(arguments: ToolArguments(values: ["path": .filePath(URL(fileURLWithPath: "/tmp"))]))
        XCTAssertTrue(valid.isValid)
        let invalid = tool.validate(arguments: ToolArguments())
        XCTAssertFalse(invalid.isValid)
    }

    func testFileWriteToolPermission() {
        let tool = FileWriteTool()
        XCTAssertEqual(tool.schema.permission, .high)
    }

    func testFileWriteToolValidation() {
        let tool = FileWriteTool()
        let valid = tool.validate(arguments: ToolArguments(values: [
            "path": .filePath(URL(fileURLWithPath: "/tmp/test")),
            "content": .string("hello")
        ]))
        XCTAssertTrue(valid.isValid)
        let invalid = tool.validate(arguments: ToolArguments())
        XCTAssertFalse(invalid.isValid)
    }

    func testFileDeleteToolPermission() {
        let tool = FileDeleteTool()
        XCTAssertEqual(tool.schema.permission, .high)
    }

    func testCommandExecuteToolPermission() {
        let tool = CommandExecuteTool()
        XCTAssertEqual(tool.schema.permission, .high)
    }

    func testFileReadToolExecute() async throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).txt")
        try "test content".write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let tool = FileReadTool()
        let output = try await tool.execute(
            arguments: ToolArguments(values: ["path": .filePath(tmpFile)]),
            session: AgentSessionID()
        )
        XCTAssertEqual(output.text, "test content")
    }

    func testFileWriteToolExecute() async throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("write-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let tool = FileWriteTool()
        let output = try await tool.execute(
            arguments: ToolArguments(values: [
                "path": .filePath(tmpFile),
                "content": .string("written content")
            ]),
            session: AgentSessionID()
        )
        XCTAssertNotNil(output.text)
        let content = try String(contentsOf: tmpFile, encoding: .utf8)
        XCTAssertEqual(content, "written content")
    }

    func testToolArgumentsHelpers() {
        let args = ToolArguments(values: [
            "str": .string("hello"),
            "int": .integer(42),
            "bool": .boolean(true),
            "path": .filePath(URL(fileURLWithPath: "/tmp"))
        ])
        XCTAssertEqual(args.string("str"), "hello")
        XCTAssertEqual(args.integer("int"), 42)
        XCTAssertEqual(args.boolean("bool"), true)
        XCTAssertNotNil(args.filePath("path"))
        XCTAssertNil(args.string("nonexistent"))
    }
}
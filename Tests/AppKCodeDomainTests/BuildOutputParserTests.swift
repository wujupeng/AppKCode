import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeShared

final class BuildOutputParserTests: XCTestCase {
    func testParseSwiftError() {
        let parser = BuildOutputParser()
        let output = "/path/to/file.swift:10:5: error: use of unresolved identifier 'foo'"
        let problems = parser.parse(output)
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems[0].file, "/path/to/file.swift")
        XCTAssertEqual(problems[0].line, 10)
        XCTAssertEqual(problems[0].column, 5)
        XCTAssertEqual(problems[0].severity, .error)
        XCTAssertTrue(problems[0].message.contains("unresolved identifier"))
    }

    func testParseSwiftWarning() {
        let parser = BuildOutputParser()
        let output = "/path/to/file.swift:20:3: warning: variable 'x' was never used"
        let problems = parser.parse(output)
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems[0].severity, .warning)
    }

    func testParseClangError() {
        let parser = BuildOutputParser()
        let output = "/path/to/main.c:15:10: error: expected ';'"
        let problems = parser.parse(output)
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems[0].file, "/path/to/main.c")
        XCTAssertEqual(problems[0].line, 15)
        XCTAssertEqual(problems[0].severity, .error)
    }

    func testParseGoError() {
        let parser = BuildOutputParser()
        let output = "/path/to/main.go:5:2: undefined: foo"
        let problems = parser.parse(output)
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems[0].file, "/path/to/main.go")
        XCTAssertEqual(problems[0].severity, .error)
    }

    func testParseCMakeError() {
        let parser = BuildOutputParser()
        let output = "CMake Error at CMakeLists.txt:10 (message): something went wrong"
        let problems = parser.parse(output)
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems[0].severity, .error)
    }

    func testParseMultipleLines() {
        let parser = BuildOutputParser()
        let output = """
        /path/a.swift:1:1: error: first error
        /path/b.swift:2:3: warning: second warning
        /path/c.swift:4:5: error: third error
        """
        let problems = parser.parse(output)
        XCTAssertEqual(problems.count, 3)
        XCTAssertEqual(problems[0].severity, .error)
        XCTAssertEqual(problems[1].severity, .warning)
        XCTAssertEqual(problems[2].severity, .error)
    }

    func testParseNoErrors() {
        let parser = BuildOutputParser()
        let output = "Build Succeeded"
        let problems = parser.parse(output)
        XCTAssertEqual(problems.count, 0)
    }
}

final class ProblemMapperTests: XCTestCase {
    func testMergeDeduplicates() {
        let mapper = ProblemMapper()
        let p1 = ProblemItem(file: "a.swift", line: 1, column: 1, severity: .error, message: "err", source: .build)
        let p2 = ProblemItem(file: "a.swift", line: 1, column: 1, severity: .error, message: "err", source: .lsp)
        let p3 = ProblemItem(file: "b.swift", line: 2, column: 0, severity: .warning, message: "warn", source: .build)
        let merged = mapper.merge(problems: [p1, p3], diagnostics: [p2])
        XCTAssertEqual(merged.count, 2)
    }

    func testMergeSortsBySeverity() {
        let mapper = ProblemMapper()
        let warning = ProblemItem(file: "b.swift", line: 2, column: 0, severity: .warning, message: "w", source: .build)
        let error = ProblemItem(file: "a.swift", line: 1, column: 0, severity: .error, message: "e", source: .build)
        let merged = mapper.merge(problems: [warning], diagnostics: [error])
        XCTAssertEqual(merged[0].severity, .error)
        XCTAssertEqual(merged[1].severity, .warning)
    }
}

final class BuildConfigurationManagerTests: XCTestCase {
    func testDefaultConfiguration() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = BuildConfigurationManager(projectRoot: tempDir)
        XCTAssertEqual(manager.configuration.name, "Debug")
        XCTAssertTrue(manager.configuration.isDebug)
    }

    func testSetAndSaveConfiguration() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = BuildConfigurationManager(projectRoot: tempDir)
        manager.setConfiguration(.release)
        XCTAssertEqual(manager.configuration.name, "Release")

        let manager2 = BuildConfigurationManager(projectRoot: tempDir)
        manager2.load()
        XCTAssertEqual(manager2.configuration.name, "Release")
    }

    func testAvailableConfigurations() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = BuildConfigurationManager(projectRoot: tempDir)
        XCTAssertEqual(manager.availableConfigurations.count, 2)
    }
}

final class TestResultManagerTests: XCTestCase {
    func testUpdateAndQuery() {
        let manager = TestResultManager()
        let report1 = TestReport(passed: 5, failed: 1, skipped: 0, failures: [])
        let report2 = TestReport(passed: 3, failed: 2, skipped: 1, failures: [])
        manager.update(report1)
        manager.update(report2)
        XCTAssertEqual(manager.totalPassed, 8)
        XCTAssertEqual(manager.totalFailed, 3)
        XCTAssertEqual(manager.totalSkipped, 1)
    }

    func testClear() {
        let manager = TestResultManager()
        manager.update(TestReport(passed: 1, failed: 1, skipped: 0, failures: []))
        manager.clear()
        XCTAssertNil(manager.lastReport)
        XCTAssertEqual(manager.totalPassed, 0)
    }
}
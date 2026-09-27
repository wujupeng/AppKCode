import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeShared

final class BuildTestServiceTests: XCTestCase {
    func testDetectSwiftBuild() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "// swift-tools-version: 5.9".write(to: tempDir.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let service = BuildTestService()
        let tool = service.detectBuildTool(at: tempDir)
        XCTAssertEqual(tool, .swiftBuild)
    }

    func testDetectCMake() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "cmake_minimum_required(VERSION 3.0)".write(to: tempDir.appendingPathComponent("CMakeLists.txt"), atomically: true, encoding: .utf8)

        let service = BuildTestService()
        let tool = service.detectBuildTool(at: tempDir)
        XCTAssertEqual(tool, .cmake)
    }

    func testDetectNoBuildTool() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = BuildTestService()
        let tool = service.detectBuildTool(at: tempDir)
        XCTAssertNil(tool)
    }
}

final class TestReportParserTests: XCTestCase {
    func testParsePassedTests() {
        let output = """
        Test Case 'testA' passed (0.001 seconds)
        Test Case 'testB' passed (0.002 seconds)
        """
        let report = TestReportParser.parse(output: output, exitCode: 0)
        XCTAssertEqual(report.passed, 2)
        XCTAssertEqual(report.failed, 0)
    }

    func testParseFailedTests() {
        let output = """
        Test Case 'testA' passed (0.001 seconds)
        Test Case 'testB' failed (0.002 seconds)
        """
        let report = TestReportParser.parse(output: output, exitCode: 1)
        XCTAssertEqual(report.passed, 1)
        XCTAssertEqual(report.failed, 1)
        XCTAssertEqual(report.failures.count, 1)
    }
}
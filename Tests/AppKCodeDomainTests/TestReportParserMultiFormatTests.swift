import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeShared

final class TestReportParserMultiFormatTests: XCTestCase {
    func testParseSwiftTest() {
        let output = """
        Test Case 'testA' passed (0.001 seconds)
        Test Case 'testB' passed (0.002 seconds)
        Test Case 'testC' failed (0.003 seconds)
        """
        let report = TestReportParser.parse(output: output, exitCode: 1)
        XCTAssertEqual(report.passed, 2)
        XCTAssertEqual(report.failed, 1)
    }

    func testParseGoTest() {
        let output = """
        === RUN   TestAdd
        --- PASS: TestAdd (0.00s)
        === RUN   TestSub
        --- FAIL: TestSub (0.00s)
        === RUN   TestSkip
        --- SKIP: TestSkip (0.00s)
        """
        let report = TestReportParser.parse(output: output, exitCode: 1)
        XCTAssertEqual(report.passed, 1)
        XCTAssertEqual(report.failed, 1)
        XCTAssertEqual(report.skipped, 1)
    }

    func testParsePytest() {
        let output = """
        tests/test_a.py::test_add PASSED
        tests/test_a.py::test_sub FAILED
        tests/test_a.py::test_skip SKIPPED
        """
        let report = TestReportParser.parse(output: output, exitCode: 1)
        XCTAssertEqual(report.passed, 1)
        XCTAssertEqual(report.failed, 1)
        XCTAssertEqual(report.skipped, 1)
    }

    func testParseEmptyOutputFailure() {
        let report = TestReportParser.parse(output: "", exitCode: 1)
        XCTAssertEqual(report.failed, 1)
    }

    func testParseEmptyOutputSuccess() {
        let report = TestReportParser.parse(output: "", exitCode: 0)
        XCTAssertEqual(report.passed, 0)
        XCTAssertEqual(report.failed, 0)
    }
}
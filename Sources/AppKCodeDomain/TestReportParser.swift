import Foundation
import AppKCodeShared

public enum TestReportParser {
    public static func parse(output: String, exitCode: Int32) -> TestReport {
        var passed = 0
        var failed = 0
        var skipped = 0
        var failures: [TestFailure] = []

        for line in output.split(separator: "\n") {
            let lineStr = String(line)
            if lineStr.contains("Test Case") && lineStr.contains("passed") {
                passed += 1
            } else if lineStr.contains("Test Case") && lineStr.contains("failed") {
                failed += 1
                let testName = extractTestName(from: lineStr)
                failures.append(TestFailure(testName: testName, reason: "Test failed", file: nil, line: nil))
            } else if lineStr.contains("Test Suite") && lineStr.contains("skipped") {
                skipped += 1
            } else if lineStr.contains("error:") {
                let reason = lineStr.trimmingCharacters(in: .whitespaces)
                if !failures.isEmpty {
                    let last = failures.removeLast()
                    failures.append(TestFailure(testName: last.testName, reason: reason, file: last.file, line: last.line))
                }
            } else if lineStr.contains(".swift:") && lineStr.contains(": error:") {
                let parts = lineStr.components(separatedBy: ":")
                if parts.count >= 2 {
                    let file = parts[0]
                    let line = Int(parts[1])
                    if !failures.isEmpty {
                        let last = failures.removeLast()
                        failures.append(TestFailure(testName: last.testName, reason: last.reason, file: file, line: line))
                    }
                }
            }
        }

        if passed == 0 && failed == 0 && skipped == 0 && exitCode != 0 {
            failed = 1
            failures.append(TestFailure(testName: "Unknown", reason: "Test execution failed with exit code \(exitCode)"))
        }

        return TestReport(passed: passed, failed: failed, skipped: skipped, failures: failures)
    }

    private static func extractTestName(from line: String) -> String {
        if let range = line.range(of: "'") {
            let after = line[range.upperBound...]
            if let endRange = after.range(of: "'") {
                return String(after[..<endRange.lowerBound])
            }
        }
        return "Unknown"
    }
}
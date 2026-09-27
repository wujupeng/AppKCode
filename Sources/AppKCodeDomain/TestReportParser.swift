import Foundation
import AppKCodeShared

public enum TestReportParser {
    public static func parse(output: String, exitCode: Int32) -> TestReport {
        if looksLikeSwiftTest(output) {
            return parseSwiftTest(output: output, exitCode: exitCode)
        }
        if looksLikeGoTest(output) {
            return parseGoTest(output: output, exitCode: exitCode)
        }
        if looksLikePytest(output) {
            return parsePytest(output: output, exitCode: exitCode)
        }
        if looksLikeJest(output) {
            return parseJest(output: output, exitCode: exitCode)
        }
        return parseSwiftTest(output: output, exitCode: exitCode)
    }

    private static func looksLikeSwiftTest(_ output: String) -> Bool {
        output.contains("Test Case") || output.contains("Test Suite")
    }

    private static func looksLikeGoTest(_ output: String) -> Bool {
        output.contains("=== RUN") || output.contains("--- PASS") || output.contains("--- FAIL")
    }

    private static func looksLikePytest(_ output: String) -> Bool {
        output.contains("PASSED") || output.contains("FAILED") || output.contains("pytest")
    }

    private static func looksLikeJest(_ output: String) -> Bool {
        output.contains("✓") || output.contains("✗") || output.contains("Tests:") || output.contains("jest")
    }

    private static func parseSwiftTest(output: String, exitCode: Int32) -> TestReport {
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

    private static func parseGoTest(output: String, exitCode: Int32) -> TestReport {
        var passed = 0
        var failed = 0
        var skipped = 0
        var failures: [TestFailure] = []

        for line in output.split(separator: "\n") {
            let lineStr = String(line)
            if lineStr.contains("--- PASS") {
                passed += 1
            } else if lineStr.contains("--- FAIL") {
                failed += 1
                let testName = lineStr.replacingOccurrences(of: "--- FAIL: ", with: "").split(separator: " ").first.map(String.init) ?? "Unknown"
                failures.append(TestFailure(testName: testName, reason: "Test failed"))
            } else if lineStr.contains("--- SKIP") {
                skipped += 1
            }
        }

        if passed == 0 && failed == 0 && skipped == 0 && exitCode != 0 {
            failed = 1
            failures.append(TestFailure(testName: "Unknown", reason: "Test execution failed with exit code \(exitCode)"))
        }

        return TestReport(passed: passed, failed: failed, skipped: skipped, failures: failures)
    }

    private static func parsePytest(output: String, exitCode: Int32) -> TestReport {
        var passed = 0
        var failed = 0
        var skipped = 0
        var failures: [TestFailure] = []

        for line in output.split(separator: "\n") {
            let lineStr = String(line)
            if lineStr.contains("PASSED") {
                passed += 1
            } else if lineStr.contains("FAILED") {
                failed += 1
                let testName = lineStr.split(separator: " ").first.map(String.init) ?? "Unknown"
                failures.append(TestFailure(testName: testName, reason: "Test failed"))
            } else if lineStr.contains("SKIPPED") {
                skipped += 1
            }
        }

        if let lastLine = output.split(separator: "\n").last {
            let lineStr = String(lastLine)
            if lineStr.contains("passed") {
                let matches = lineStr.components(separatedBy: " ")
                for match in matches {
                    if let n = Int(match), lineStr.contains("\(n) passed") { passed = max(passed, n) }
                }
            }
        }

        if passed == 0 && failed == 0 && skipped == 0 && exitCode != 0 {
            failed = 1
            failures.append(TestFailure(testName: "Unknown", reason: "Test execution failed with exit code \(exitCode)"))
        }

        return TestReport(passed: passed, failed: failed, skipped: skipped, failures: failures)
    }

    private static func parseJest(output: String, exitCode: Int32) -> TestReport {
        var passed = 0
        var failed = 0
        var skipped = 0
        var failures: [TestFailure] = []

        for line in output.split(separator: "\n") {
            let lineStr = String(line)
            if lineStr.contains("✓") || lineStr.contains("✕") {
                if lineStr.contains("✓") { passed += 1 }
                else if lineStr.contains("✕") {
                    failed += 1
                    let testName = lineStr.trimmingCharacters(in: .whitespaces)
                    failures.append(TestFailure(testName: testName, reason: "Test failed"))
                }
            }
        }

        if let summaryLine = output.split(separator: "\n").first(where: { $0.contains("Tests:") }) {
            let lineStr = String(summaryLine)
            if let passedMatch = extractNumber(before: " passed", in: lineStr) { passed = passedMatch }
            if let failedMatch = extractNumber(before: " failed", in: lineStr) { failed = failedMatch }
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

    private static func extractNumber(before suffix: String, in text: String) -> Int? {
        guard let range = text.range(of: suffix) else { return nil }
        let before = text[..<range.lowerBound]
        var digits = ""
        for ch in before.reversed() {
            if ch.isNumber { digits.insert(ch, at: digits.startIndex) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }
}

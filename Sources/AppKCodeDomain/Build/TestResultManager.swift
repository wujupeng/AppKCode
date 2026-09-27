import Foundation
import AppKCodeShared

public final class TestResultManager: @unchecked Sendable {
    private(set) var lastReport: TestReport? = nil
    private(set) var allReports: [TestReport] = []
    private let lock = NSLock()

    public init() {}

    public func update(_ report: TestReport) {
        lock.lock()
        lastReport = report
        allReports.append(report)
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        lastReport = nil
        allReports = []
        lock.unlock()
    }

    public var totalPassed: Int {
        lock.lock()
        defer { lock.unlock() }
        return allReports.reduce(0) { $0 + $1.passed }
    }

    public var totalFailed: Int {
        lock.lock()
        defer { lock.unlock() }
        return allReports.reduce(0) { $0 + $1.failed }
    }

    public var totalSkipped: Int {
        lock.lock()
        defer { lock.unlock() }
        return allReports.reduce(0) { $0 + $1.skipped }
    }
}
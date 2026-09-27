import Foundation

public enum TestEvent: Sendable, Equatable {
    case started(command: String)
    case stdout(String)
    case stderr(String)
    case completed(report: TestReport)
}
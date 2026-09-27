import Foundation

public enum BuildEvent: Sendable, Equatable {
    case started(command: String)
    case stdout(String)
    case stderr(String)
    case problem(ProblemItem)
    case completed(result: BuildResult)
}
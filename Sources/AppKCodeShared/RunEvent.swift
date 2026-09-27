import Foundation

public enum RunEvent: Sendable, Equatable {
    case started(command: String)
    case stdout(String)
    case stderr(String)
    case exited(code: Int32)
}
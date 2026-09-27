import Foundation

public enum ProcessOutput: Sendable, Equatable {
    case stdout(String)
    case stderr(String)
    case exit(Int32)
}
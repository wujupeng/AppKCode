import Foundation

public enum LanguageServerStatus: Equatable, Sendable {
    case notStarted
    case starting
    case running
    case crashed(restartCount: Int)
    case stopped

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var isCrashed: Bool {
        if case .crashed = self { return true }
        return false
    }
}
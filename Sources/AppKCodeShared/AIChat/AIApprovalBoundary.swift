import Foundation

public enum AICapability: String, Sendable, Equatable, CaseIterable {
    case readContext
    case explainCode
    case suggestCode
    case generatePatchCandidate
}

public enum AIProhibitedAction: String, Sendable, Equatable, CaseIterable {
    case writeFile
    case executeCommand
    case gitCommit
    case gitPush
}

public struct AIBoundaryDecision: Sendable, Equatable {
    public let allowed: [AICapability]
    public let prohibited: [AIProhibitedAction]
    public let reason: String

    public init(allowed: [AICapability], prohibited: [AIProhibitedAction], reason: String) {
        self.allowed = allowed
        self.prohibited = prohibited
        self.reason = reason
    }
}
import Foundation

public struct AgentRequest: Sendable, Equatable {
    public let prompt: String
    public let attachedFiles: [URL]
    public let intentHint: IntentHint
    public init(prompt: String, attachedFiles: [URL] = [], intentHint: IntentHint = .unspecified) {
        self.prompt = prompt
        self.attachedFiles = attachedFiles
        self.intentHint = intentHint
    }
}

public enum IntentHint: Sendable, Equatable {
    case codeReview
    case testRun
    case bugLocate
    case refactor
    case unspecified
}

public struct AgentResponse: Sendable, Equatable {
    public let report: AgentReport
    public let evidenceChain: EvidenceChain
    public let proposedChanges: [FileChangeProposal]
    public init(report: AgentReport, evidenceChain: EvidenceChain, proposedChanges: [FileChangeProposal]) {
        self.report = report
        self.evidenceChain = evidenceChain
        self.proposedChanges = proposedChanges
    }
}

public enum AgentSessionState: Sendable, Equatable {
    case active
    case paused
    case completed
    case aborted
}

public struct ContextPackage: Sendable, Equatable {
    public let prompt: String
    public let currentFileContent: String?
    public let currentFileURL: URL?
    public let projectFileList: [URL]
    public let messages: [ContextMessage]
    public init(prompt: String, currentFileContent: String?, currentFileURL: URL?, projectFileList: [URL], messages: [ContextMessage]) {
        self.prompt = prompt
        self.currentFileContent = currentFileContent
        self.currentFileURL = currentFileURL
        self.projectFileList = projectFileList
        self.messages = messages
    }
}

public struct ContextMessage: Sendable, Equatable {
    public let role: Role
    public let content: String
    public enum Role: String, Sendable, Equatable {
        case system, user, assistant
    }
    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}
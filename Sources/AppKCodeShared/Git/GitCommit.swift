import Foundation

public struct GitCommitInfo: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sha: String
    public let shortSha: String
    public let authorName: String
    public let authorEmail: String
    public let authorDate: Date
    public let committerName: String
    public let committerEmail: String
    public let committerDate: Date
    public let message: String
    public let messageSubject: String
    public let messageBody: String
    public let parentShas: [String]

    public init(id: UUID = UUID(), sha: String, shortSha: String, authorName: String, authorEmail: String, authorDate: Date, committerName: String, committerEmail: String, committerDate: Date, message: String, messageSubject: String, messageBody: String, parentShas: [String]) {
        self.id = id
        self.sha = sha
        self.shortSha = shortSha
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.authorDate = authorDate
        self.committerName = committerName
        self.committerEmail = committerEmail
        self.committerDate = committerDate
        self.message = message
        self.messageSubject = messageSubject
        self.messageBody = messageBody
        self.parentShas = parentShas
    }
}
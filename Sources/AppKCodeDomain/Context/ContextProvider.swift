import Foundation
import AppKCodeShared

public protocol ContextProvider: Sendable {
    var source: ContextSource { get }
    func gather(context: ContextRequest) async throws -> [ContextItem]
}

public struct ContextRequest: Sendable {
    public let projectRoot: URL
    public let currentFile: URL?
    public let selection: SourceRange?
    public let openTabs: [URL]
    public let budget: ContextBudget

    public init(
        projectRoot: URL,
        currentFile: URL? = nil,
        selection: SourceRange? = nil,
        openTabs: [URL] = [],
        budget: ContextBudget = ContextBudget()
    ) {
        self.projectRoot = projectRoot
        self.currentFile = currentFile
        self.selection = selection
        self.openTabs = openTabs
        self.budget = budget
    }
}
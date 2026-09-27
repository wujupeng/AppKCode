import Foundation
import AppKCodeInfrastructure

public struct LanguageServerConfig: Sendable {
    public let executablePath: String
    public let arguments: [String]
    public let supportedLanguages: [String]
    public let initializationOptions: AnyCodable?
    public let workspaceFolders: [URL]?

    public init(executablePath: String, arguments: [String] = [], supportedLanguages: [String],
                initializationOptions: AnyCodable? = nil, workspaceFolders: [URL]? = nil) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.supportedLanguages = supportedLanguages
        self.initializationOptions = initializationOptions
        self.workspaceFolders = workspaceFolders
    }
}
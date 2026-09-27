import Foundation

public protocol LanguageServiceProvider: PluginCapability {
    func supportedLanguages() -> [String]
    func provideLanguageService(for language: String) -> LanguageService?
}
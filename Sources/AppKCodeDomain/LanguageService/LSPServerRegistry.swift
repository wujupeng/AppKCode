import Foundation
import AppKCodeInfrastructure

public final class LSPServerRegistry: ObservableObject {
    private var adapters: [String: LSPServerAdapter] = [:]
    private let workspaceRoot: URL
    private let lock = NSLock()

    @Published public private(set) var initializedLanguages: Set<String> = []

    public init(workspaceRoot: URL) {
        self.workspaceRoot = workspaceRoot
    }

    public func adapter(forLanguage language: String) -> LSPServerAdapter? {
        lock.lock()
        if let existing = adapters[language] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let adapter = createAdapter(forLanguage: language)
        guard let adapter = adapter else { return nil }

        lock.lock()
        adapters[language] = adapter
        lock.unlock()
        return adapter
    }

    public func adapter(forURL url: URL) -> LSPServerAdapter? {
        let language = LanguageIdentifier.identify(url: url)
        return adapter(forLanguage: language)
    }

    public func adapter(forFileExtension ext: String) -> LSPServerAdapter? {
        let language = LanguageIdentifier.identify(filename: "test.\(ext)")
        return adapter(forLanguage: language)
    }

    private func createAdapter(forLanguage language: String) -> LSPServerAdapter? {
        switch language {
        case "Swift":
            let adapter = SourceKitLSPAdapter()
            adapter.checkAvailability()
            return adapter.isAvailable ? adapter : nil
        case "C", "C++", "Objective-C":
            let adapter = ClangdAdapter()
            adapter.checkAvailability()
            return adapter.isAvailable ? adapter : nil
        case "Go":
            let adapter = GoplsAdapter()
            adapter.checkAvailability()
            return adapter.isAvailable ? adapter : nil
        case "Python":
            let adapter = PythonLSPAdapter()
            adapter.checkAvailability()
            return adapter.isAvailable ? adapter : nil
        case "JavaScript", "TypeScript":
            let adapter = TypeScriptLSPAdapter()
            adapter.checkAvailability()
            return adapter.isAvailable ? adapter : nil
        default:
            return nil
        }
    }

    public func supportedLanguages() -> [String] {
        var supported: [String] = []
        for language in ["Swift", "C", "C++", "Objective-C", "Go", "Python", "JavaScript", "TypeScript"] {
            if let adapter = createAdapter(forLanguage: language) {
                supported.append(language)
                _ = adapter
            }
        }
        return supported
    }

    public func initializeLanguage(_ language: String) async throws {
        guard let adapter = adapter(forLanguage: language) else {
            throw LSPAdapterError.languageNotSupported(language)
        }

        if !initializedLanguages.contains(language) {
            try await adapter.initialize(workspaceRoot: workspaceRoot)
            lock.lock()
            initializedLanguages.insert(language)
            lock.unlock()
        }
    }

    public func shutdownAll() async throws {
        lock.lock()
        let allAdapters = Array(adapters.values)
        adapters.removeAll()
        initializedLanguages.removeAll()
        lock.unlock()

        for adapter in allAdapters {
            try? await adapter.shutdown()
        }
    }
}
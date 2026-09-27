import Foundation

public enum LanguageIdentifier {
    private static let extensions: [String: String] = [
        "swift": "Swift", "m": "Objective-C", "mm": "Objective-C++",
        "c": "C", "h": "C", "cpp": "C++", "cc": "C++", "cxx": "C++", "hpp": "C++",
        "py": "Python", "go": "Go",
        "js": "JavaScript", "jsx": "JavaScript", "mjs": "JavaScript",
        "ts": "TypeScript", "tsx": "TypeScript",
        "json": "JSON", "yaml": "YAML", "yml": "YAML",
        "md": "Markdown", "markdown": "Markdown",
    ]

    public static let supportedLanguages: [String] = [
        "Swift", "Objective-C", "C", "C++", "Python", "Go",
        "JavaScript", "TypeScript", "JSON", "YAML", "Markdown"
    ]

    public static func identify(url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return extensions[ext] ?? "Plain Text"
    }

    public static func identify(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        return extensions[ext] ?? "Plain Text"
    }

    public static func isSupported(_ language: String) -> Bool {
        supportedLanguages.contains(language)
    }
}
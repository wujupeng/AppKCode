import Foundation
import AppKCodeInfrastructure

public final class GoplsAdapter: LSPServerAdapter {
    public init() {
        super.init(config: LanguageServerConfig(
            executablePath: "gopls",
            arguments: ["serve"],
            supportedLanguages: ["Go"]
        ))
    }

    public override func detectExecutable() -> String? {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let candidates = [
            "\(home)/go/bin/gopls",
            "/usr/local/go/bin/gopls",
            "/usr/local/bin/gopls",
            "/opt/homebrew/bin/gopls",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}
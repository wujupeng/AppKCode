import Foundation
import AppKCodeInfrastructure

public final class TypeScriptLSPAdapter: LSPServerAdapter {
    public init() {
        super.init(config: LanguageServerConfig(
            executablePath: "typescript-language-server",
            arguments: ["--stdio"],
            supportedLanguages: ["JavaScript", "TypeScript"]
        ))
    }

    public override func detectExecutable() -> String? {
        let candidates = [
            "/usr/local/bin/typescript-language-server",
            "/opt/homebrew/bin/typescript-language-server",
            "/usr/bin/typescript-language-server",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}
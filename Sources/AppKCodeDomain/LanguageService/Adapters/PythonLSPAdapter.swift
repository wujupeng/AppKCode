import Foundation
import AppKCodeInfrastructure

public final class PythonLSPAdapter: LSPServerAdapter {
    public init() {
        super.init(config: LanguageServerConfig(
            executablePath: "pyright-langserver",
            arguments: ["--stdio"],
            supportedLanguages: ["Python"]
        ))
    }

    public override func detectExecutable() -> String? {
        let candidates = [
            "/usr/local/bin/pyright-langserver",
            "/opt/homebrew/bin/pyright-langserver",
            "/usr/bin/pyright-langserver",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let pylspCandidates = [
            "/usr/local/bin/pylsp",
            "/opt/homebrew/bin/pylsp",
        ]

        for path in pylspCandidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}
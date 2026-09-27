import Foundation
import AppKCodeInfrastructure

public final class ClangdAdapter: LSPServerAdapter {
    public init() {
        super.init(config: LanguageServerConfig(
            executablePath: "clangd",
            arguments: ["--background-index", "--clang-tidy"],
            supportedLanguages: ["C", "C++", "Objective-C"]
        ))
    }

    public override func detectExecutable() -> String? {
        let candidates = [
            "/usr/bin/clangd",
            "/usr/local/bin/clangd",
            "/opt/homebrew/bin/clangd",
            "/opt/llvm/bin/clangd",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        if let path = LSPExecutableFinder.findViaXcrun("clangd") {
            return path
        }

        return nil
    }
}
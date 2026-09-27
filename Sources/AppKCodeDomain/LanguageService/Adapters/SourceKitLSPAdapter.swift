import Foundation
import AppKCodeInfrastructure

public final class SourceKitLSPAdapter: LSPServerAdapter {
    public init() {
        super.init(config: LanguageServerConfig(
            executablePath: "sourcekit-lsp",
            arguments: [],
            supportedLanguages: ["Swift"]
        ))
    }

    public override func detectExecutable() -> String? {
        let candidates = [
            "/usr/bin/sourcekit-lsp",
            "/opt/swift/toolchain/usr/bin/sourcekit-lsp",
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
            "/Users/hunt/Downloads/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        if let path = LSPExecutableFinder.findViaXcrun("sourcekit-lsp") {
            return path
        }

        return nil
    }
}
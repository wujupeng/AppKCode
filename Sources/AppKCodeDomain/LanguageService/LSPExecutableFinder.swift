import Foundation

public enum LSPExecutableFinder {
    public static func findViaXcrun(_ name: String) -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/xcrun"
        process.arguments = ["--find", name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {}
        return nil
    }

    public static func findInPath(_ name: String) -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/which"
        process.arguments = [name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {}
        return nil
    }

    public static func checkCandidates(_ paths: [String]) -> String? {
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
}
import Foundation
import AppKCodeShared

// MARK: - Runtime Detection Result (TASK-006.5)

public struct RuntimeDetection: Sendable, Codable, Equatable {
    public let found: Bool
    public let path: String
    public let version: SemVer?
    public let architecture: Architecture
    public let meetsRequirement: Bool

    public init(
        found: Bool,
        path: String,
        version: SemVer? = nil,
        architecture: Architecture = .x86_64,
        meetsRequirement: Bool = false
    ) {
        self.found = found
        self.path = path
        self.version = version
        self.architecture = architecture
        self.meetsRequirement = meetsRequirement
    }
}

// MARK: - Runtime Detector Protocol (TASK-006.1)

public protocol RuntimeDetector: Sendable {
    func detectNodeJS() async throws -> RuntimeDetection
    func detectJDK() async throws -> RuntimeDetection
    func verifyArchitecture(path: String) async throws -> Architecture
}

// MARK: - Runtime Detector Impl (TASK-006.2~006.6, H1)

public final class RuntimeDetectorImpl: RuntimeDetector, @unchecked Sendable {
    public init() {}

    public func detectNodeJS() async throws -> RuntimeDetection {
        let whichResult = try await runCommand(executable: "/usr/bin/which", arguments: ["node"])
        guard !whichResult.isEmpty else {
            return RuntimeDetection(found: false, path: "")
        }

        let nodePath = whichResult.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionResult = try await runCommand(executable: nodePath, arguments: ["--version"])
        let version = parseNodeVersion(versionResult.trimmingCharacters(in: .whitespacesAndNewlines))

        let arch = try await verifyArchitecture(path: nodePath)

        let meetsRequirement: Bool
        if let v = version {
            meetsRequirement = v >= SemVer(20, 0, 0) && arch == .x86_64
        } else {
            meetsRequirement = false
        }

        return RuntimeDetection(
            found: true,
            path: nodePath,
            version: version,
            architecture: arch,
            meetsRequirement: meetsRequirement
        )
    }

    public func detectJDK() async throws -> RuntimeDetection {
        let javaHomeResult = try await runCommand(
            executable: "/usr/libexec/java_home",
            arguments: ["-v", "17"]
        )
        guard !javaHomeResult.isEmpty else {
            return RuntimeDetection(found: false, path: "")
        }

        let javaHome = javaHomeResult.trimmingCharacters(in: .whitespacesAndNewlines)
        let javaPath = (javaHome as NSString).appendingPathComponent("bin/java")

        let versionResult = try await runCommand(executable: javaPath, arguments: ["-version"])
        let version = parseJDKVersion(versionResult)

        let arch = try await verifyArchitecture(path: javaPath)

        let meetsRequirement: Bool
        if let v = version {
            meetsRequirement = v >= SemVer(17, 0, 0) && arch == .x86_64
        } else {
            meetsRequirement = false
        }

        return RuntimeDetection(
            found: true,
            path: javaPath,
            version: version,
            architecture: arch,
            meetsRequirement: meetsRequirement
        )
    }

    public func verifyArchitecture(path: String) async throws -> Architecture {
        let fileResult = try await runCommand(executable: "/usr/bin/file", arguments: [path])

        if fileResult.contains("x86_64") {
            if fileResult.contains("arm64") || fileResult.contains("universal") {
                return .universal
            }
            return .x86_64
        }
        if fileResult.contains("arm64") {
            return .arm64
        }
        return .x86_64
    }

    private func runCommand(executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }

    private func parseNodeVersion(_ output: String) -> SemVer? {
        guard output.hasPrefix("v") else { return nil }
        let versionStr = String(output.dropFirst())
        return parseSemVer(versionStr)
    }

    private func parseJDKVersion(_ output: String) -> SemVer? {
        let lines = output.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("version") {
                if let range = trimmed.range(of: #""(\d+)"# , options: .regularExpression) {
                    let match = trimmed[range]
                    let numStr = match.filter { $0.isNumber }
                    if let major = Int(numStr) {
                        return SemVer(major, 0, 0)
                    }
                }
            }
        }
        return nil
    }

    private func parseSemVer(_ str: String) -> SemVer? {
        let parts = str.split(separator: ".")
        guard parts.count >= 3 else { return nil }
        guard let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
        let patchStr = parts[2].split(separator: "-").first.map(String.init) ?? String(parts[2])
        guard let patch = Int(patchStr) else { return nil }
        return SemVer(major, minor, patch)
    }
}
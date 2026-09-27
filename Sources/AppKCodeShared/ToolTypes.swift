import Foundation

public enum ToolCall: Sendable, Equatable {
    case readFile(url: URL)
    case writeFile(url: URL, content: String)
    case searchCode(query: String, directory: URL)
    case runBuild(tool: BuildTool, directory: URL)
    case runTest(tool: BuildTool, directory: URL)
    case gitStatus(repo: URL)
    case gitDiff(repo: URL)
    case lspRequest(method: String, params: [String: String])
    case mcpCall(server: String, tool: String, args: [String: String])
}

public enum BuildTool: Sendable, Equatable {
    case swiftBuild
    case xcodebuild
    case cmake
    case make
    case goBuild

    public var binaryName: String {
        switch self {
        case .swiftBuild: return "swift"
        case .xcodebuild: return "xcodebuild"
        case .cmake: return "cmake"
        case .make: return "make"
        case .goBuild: return "go"
        }
    }

    public var buildCommand: String {
        switch self {
        case .swiftBuild: return "swift build"
        case .xcodebuild: return "xcodebuild build"
        case .cmake: return "cmake --build ."
        case .make: return "make"
        case .goBuild: return "go build"
        }
    }

    public var testCommand: String {
        switch self {
        case .swiftBuild: return "swift test"
        case .xcodebuild: return "xcodebuild test"
        case .cmake: return "ctest"
        case .make: return "make test"
        case .goBuild: return "go test"
        }
    }

    public var markerFile: String {
        switch self {
        case .swiftBuild: return "Package.swift"
        case .xcodebuild: return ".xcodeproj"
        case .cmake: return "CMakeLists.txt"
        case .make: return "Makefile"
        case .goBuild: return "go.mod"
        }
    }
}

public struct ToolResult: Sendable, Equatable {
    public let success: Bool
    public let output: String
    public let error: String?
    public let evidenceID: String?
    public init(success: Bool, output: String, error: String? = nil, evidenceID: String? = nil) {
        self.success = success
        self.output = output
        self.error = error
        self.evidenceID = evidenceID
    }
}

public struct ProcessResult: Sendable, Equatable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public struct BuildResult: Sendable, Equatable {
    public let success: Bool
    public let output: String
    public let tool: BuildTool
    public init(success: Bool, output: String, tool: BuildTool) {
        self.success = success
        self.output = output
        self.tool = tool
    }
}

public struct TestReport: Sendable, Equatable {
    public let passed: Int
    public let failed: Int
    public let skipped: Int
    public let failures: [TestFailure]
    public init(passed: Int, failed: Int, skipped: Int, failures: [TestFailure]) {
        self.passed = passed
        self.failed = failed
        self.skipped = skipped
        self.failures = failures
    }
}

public struct TestFailure: Sendable, Equatable {
    public let testName: String
    public let reason: String
    public let file: String?
    public let line: Int?
    public init(testName: String, reason: String, file: String? = nil, line: Int? = nil) {
        self.testName = testName
        self.reason = reason
        self.file = file
        self.line = line
    }
}
import Foundation

public struct Command: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String: String]
    public let workingDirectory: URL?
    public let timeout: TimeInterval?

    public init(executable: String,
                arguments: [String] = [],
                environment: [String: String] = [:],
                workingDirectory: URL? = nil,
                timeout: TimeInterval? = nil) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }

    public var commandLine: String {
        ([executable] + arguments).joined(separator: " ")
    }

    public static func build(tool: BuildTool, configuration: BuildConfiguration, projectRoot: URL) -> Command {
        switch tool {
        case .swiftBuild:
            return Command(executable: "swift", arguments: ["build", "--configuration", configuration.swiftConfigName], workingDirectory: projectRoot)
        case .xcodebuild:
            var args = ["build"]
            if !configuration.xcodeScheme.isEmpty { args += ["-scheme", configuration.xcodeScheme] }
            args += ["-configuration", configuration.name]
            return Command(executable: "xcodebuild", arguments: args, workingDirectory: projectRoot)
        case .cmake:
            return Command(executable: "cmake", arguments: ["--build", "."], workingDirectory: projectRoot)
        case .make:
            return Command(executable: "make", arguments: [], workingDirectory: projectRoot)
        case .goBuild:
            return Command(executable: "go", arguments: ["build", "./..."], workingDirectory: projectRoot)
        }
    }

    public static func test(tool: BuildTool, configuration: BuildConfiguration, projectRoot: URL) -> Command {
        switch tool {
        case .swiftBuild:
            return Command(executable: "swift", arguments: ["test"], workingDirectory: projectRoot)
        case .xcodebuild:
            var args = ["test"]
            if !configuration.xcodeScheme.isEmpty { args += ["-scheme", configuration.xcodeScheme] }
            args += ["-configuration", configuration.name]
            return Command(executable: "xcodebuild", arguments: args, workingDirectory: projectRoot)
        case .cmake:
            return Command(executable: "ctest", arguments: [], workingDirectory: projectRoot)
        case .make:
            return Command(executable: "make", arguments: ["test"], workingDirectory: projectRoot)
        case .goBuild:
            return Command(executable: "go", arguments: ["test", "./..."], workingDirectory: projectRoot)
        }
    }

    public static func clean(tool: BuildTool, projectRoot: URL) -> Command {
        switch tool {
        case .swiftBuild:
            return Command(executable: "swift", arguments: ["package", "clean"], workingDirectory: projectRoot)
        case .xcodebuild:
            return Command(executable: "xcodebuild", arguments: ["clean"], workingDirectory: projectRoot)
        case .cmake:
            return Command(executable: "cmake", arguments: ["--build", ".", "--target", "clean"], workingDirectory: projectRoot)
        case .make:
            return Command(executable: "make", arguments: ["clean"], workingDirectory: projectRoot)
        case .goBuild:
            return Command(executable: "go", arguments: ["clean", "-cache"], workingDirectory: projectRoot)
        }
    }

    public static func run(executable: URL, arguments: [String], workingDirectory: URL?, environment: [String: String]) -> Command {
        Command(executable: executable.path, arguments: arguments, environment: environment, workingDirectory: workingDirectory)
    }

    public func withEnvironment(_ env: [String: String]) -> Command {
        var merged = self.environment
        for (k, v) in env { merged[k] = v }
        return Command(executable: executable, arguments: arguments, environment: merged, workingDirectory: workingDirectory, timeout: timeout)
    }

    public func withTimeout(_ timeout: TimeInterval) -> Command {
        Command(executable: executable, arguments: arguments, environment: environment, workingDirectory: workingDirectory, timeout: timeout)
    }
}
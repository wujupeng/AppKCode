import XCTest
@testable import AppKCodeShared

final class CommandTests: XCTestCase {
    func testCommandBasicConstruction() {
        let cmd = Command(executable: "/bin/echo", arguments: ["hello", "world"])
        XCTAssertEqual(cmd.executable, "/bin/echo")
        XCTAssertEqual(cmd.arguments, ["hello", "world"])
        XCTAssertEqual(cmd.environment, [:])
        XCTAssertNil(cmd.workingDirectory)
        XCTAssertNil(cmd.timeout)
    }

    func testCommandLineDisplay() {
        let cmd = Command(executable: "swift", arguments: ["build", "--configuration", "release"])
        XCTAssertEqual(cmd.commandLine, "swift build --configuration release")
    }

    func testCommandEquatable() {
        let cmd1 = Command(executable: "swift", arguments: ["build"])
        let cmd2 = Command(executable: "swift", arguments: ["build"])
        let cmd3 = Command(executable: "swift", arguments: ["test"])
        XCTAssertEqual(cmd1, cmd2)
        XCTAssertNotEqual(cmd1, cmd3)
    }

    func testBuildCommandForSwift() {
        let projectRoot = URL(fileURLWithPath: "/tmp/project")
        let cmd = Command.build(tool: .swiftBuild, configuration: .debug, projectRoot: projectRoot)
        XCTAssertEqual(cmd.executable, "swift")
        XCTAssertEqual(cmd.arguments, ["build", "--configuration", "debug"])
        XCTAssertEqual(cmd.workingDirectory, projectRoot)
    }

    func testBuildCommandForSwiftRelease() {
        let projectRoot = URL(fileURLWithPath: "/tmp/project")
        let cmd = Command.build(tool: .swiftBuild, configuration: .release, projectRoot: projectRoot)
        XCTAssertEqual(cmd.arguments, ["build", "--configuration", "release"])
    }

    func testTestCommandForSwift() {
        let projectRoot = URL(fileURLWithPath: "/tmp/project")
        let cmd = Command.test(tool: .swiftBuild, configuration: .debug, projectRoot: projectRoot)
        XCTAssertEqual(cmd.executable, "swift")
        XCTAssertEqual(cmd.arguments, ["test"])
        XCTAssertEqual(cmd.workingDirectory, projectRoot)
    }

    func testTestCommandForGo() {
        let projectRoot = URL(fileURLWithPath: "/tmp/project")
        let cmd = Command.test(tool: .goBuild, configuration: .debug, projectRoot: projectRoot)
        XCTAssertEqual(cmd.executable, "go")
        XCTAssertEqual(cmd.arguments, ["test", "./..."])
    }

    func testCleanCommandForSwift() {
        let projectRoot = URL(fileURLWithPath: "/tmp/project")
        let cmd = Command.clean(tool: .swiftBuild, projectRoot: projectRoot)
        XCTAssertEqual(cmd.executable, "swift")
        XCTAssertEqual(cmd.arguments, ["package", "clean"])
        XCTAssertEqual(cmd.workingDirectory, projectRoot)
    }

    func testCleanCommandForMake() {
        let projectRoot = URL(fileURLWithPath: "/tmp/project")
        let cmd = Command.clean(tool: .make, projectRoot: projectRoot)
        XCTAssertEqual(cmd.executable, "make")
        XCTAssertEqual(cmd.arguments, ["clean"])
    }

    func testRunCommand() {
        let execURL = URL(fileURLWithPath: "/usr/bin/ls")
        let cmd = Command.run(executable: execURL, arguments: ["-la"], workingDirectory: URL(fileURLWithPath: "/tmp"), environment: ["FOO": "bar"])
        XCTAssertEqual(cmd.executable, "/usr/bin/ls")
        XCTAssertEqual(cmd.arguments, ["-la"])
        XCTAssertEqual(cmd.environment, ["FOO": "bar"])
        XCTAssertEqual(cmd.workingDirectory?.path, "/tmp")
    }

    func testWithEnvironmentMerging() {
        let cmd = Command(executable: "swift", arguments: ["build"], environment: ["PATH": "/usr/bin"])
        let merged = cmd.withEnvironment(["HOME": "/tmp", "PATH": "/opt/bin"])
        XCTAssertEqual(merged.environment, ["PATH": "/opt/bin", "HOME": "/tmp"])
    }

    func testWithTimeout() {
        let cmd = Command(executable: "swift", arguments: ["build"])
        XCTAssertNil(cmd.timeout)
        let withTimeout = cmd.withTimeout(30.0)
        XCTAssertEqual(withTimeout.timeout, 30.0)
    }

    func testSendableConformance() {
        let cmd = Command(executable: "swift", arguments: ["build"])
        let sendable: any Sendable = cmd
        XCTAssertNotNil(sendable)
    }
}

final class BuildConfigurationTests: XCTestCase {
    func testDebugConfig() {
        let config = BuildConfiguration.debug
        XCTAssertEqual(config.name, "Debug")
        XCTAssertTrue(config.isDebug)
        XCTAssertEqual(config.swiftConfigName, "debug")
    }

    func testReleaseConfig() {
        let config = BuildConfiguration.release
        XCTAssertEqual(config.name, "Release")
        XCTAssertFalse(config.isDebug)
        XCTAssertEqual(config.swiftConfigName, "release")
    }

    func testCustomConfig() {
        let config = BuildConfiguration(name: "Custom-Opt", isDebug: false, xcodeScheme: "MyApp")
        XCTAssertEqual(config.name, "Custom-Opt")
        XCTAssertEqual(config.xcodeScheme, "MyApp")
    }
}

final class ProblemItemTests: XCTestCase {
    func testProblemItemCreation() {
        let item = ProblemItem(file: "main.swift", line: 10, column: 5, severity: .error, message: "missing semicolon", source: .build)
        XCTAssertEqual(item.file, "main.swift")
        XCTAssertEqual(item.line, 10)
        XCTAssertEqual(item.column, 5)
        XCTAssertEqual(item.severity, .error)
        XCTAssertEqual(item.source, .build)
    }

    func testLocationTextWithColumn() {
        let item = ProblemItem(file: "main.swift", line: 10, column: 5, severity: .error, message: "err", source: .build)
        XCTAssertEqual(item.locationText, "main.swift:10:5")
    }

    func testLocationTextWithoutColumn() {
        let item = ProblemItem(file: "main.swift", line: 10, severity: .warning, message: "warn", source: .build)
        XCTAssertEqual(item.locationText, "main.swift:10")
    }

    func testSeverityOrdering() {
        XCTAssertTrue(ProblemSeverity.error < ProblemSeverity.warning)
        XCTAssertTrue(ProblemSeverity.warning < ProblemSeverity.info)
        XCTAssertTrue(ProblemSeverity.info < ProblemSeverity.hint)
    }
}

final class ToolchainTypesTests: XCTestCase {
    func testToolchainKindExecutableNames() {
        XCTAssertEqual(ToolchainKind.swift.executableName, "swift")
        XCTAssertEqual(ToolchainKind.clang.executableName, "clang")
        XCTAssertEqual(ToolchainKind.go.executableName, "go")
        XCTAssertEqual(ToolchainKind.python.executableName, "python3")
        XCTAssertEqual(ToolchainKind.node.executableName, "node")
    }

    func testToolchainKindDisplayNames() {
        XCTAssertEqual(ToolchainKind.swift.displayName, "Swift")
        XCTAssertEqual(ToolchainKind.python.displayName, "Python")
        XCTAssertEqual(ToolchainKind.node.displayName, "Node.js")
    }

    func testToolchainKindCaseIterable() {
        XCTAssertEqual(ToolchainKind.allCases.count, 7)
    }

    func testToolchainInfoCreation() {
        let info = ToolchainInfo(kind: .swift, path: "/usr/bin/swift", version: "5.8.0", isAvailable: true)
        XCTAssertEqual(info.kind, .swift)
        XCTAssertTrue(info.isAvailable)
    }
}
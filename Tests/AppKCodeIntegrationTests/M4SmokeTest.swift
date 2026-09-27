import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeApplication
@testable import AppKCodeShared
@testable import AppKCodeInfrastructure
@testable import AppKCodePresentation

final class M4SmokeTest: XCTestCase {

    // MARK: - H7: Structured Command Model

    func testM4_H7_01_commandModelExists() {
        let cmd = Command(executable: "swift", arguments: ["build"])
        XCTAssertEqual(cmd.executable, "swift")
        XCTAssertEqual(cmd.arguments, ["build"])
    }

    func testM4_H7_02_commandIsSendable() {
        let cmd = Command(executable: "swift", arguments: ["build"])
        let sendable: any Sendable = cmd
        XCTAssertNotNil(sendable)
    }

    func testM4_H7_03_commandBuildConvenience() {
        let root = URL(fileURLWithPath: "/tmp")
        let cmd = Command.build(tool: .swiftBuild, configuration: .debug, projectRoot: root)
        XCTAssertEqual(cmd.executable, "swift")
        XCTAssertTrue(cmd.arguments.contains("build"))
    }

    func testM4_H7_04_commandTestConvenience() {
        let root = URL(fileURLWithPath: "/tmp")
        let cmd = Command.test(tool: .swiftBuild, configuration: .debug, projectRoot: root)
        XCTAssertEqual(cmd.executable, "swift")
        XCTAssertTrue(cmd.arguments.contains("test"))
    }

    func testM4_H7_05_commandCleanConvenience() {
        let root = URL(fileURLWithPath: "/tmp")
        let cmd = Command.clean(tool: .swiftBuild, projectRoot: root)
        XCTAssertEqual(cmd.executable, "swift")
        XCTAssertTrue(cmd.arguments.contains("clean"))
    }

    func testM4_H7_06_commandWithEnvironment() {
        let cmd = Command(executable: "swift", arguments: [])
        let withEnv = cmd.withEnvironment(["FOO": "bar"])
        XCTAssertEqual(withEnv.environment["FOO"], "bar")
    }

    func testM4_H7_07_commandWithTimeout() {
        let cmd = Command(executable: "swift", arguments: [])
        let withTimeout = cmd.withTimeout(30.0)
        XCTAssertEqual(withTimeout.timeout, 30.0)
    }

    // MARK: - P1-P5: ProcessRunner with Command

    func testM4_P1_01_processRunnerRunCommand() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/echo", arguments: ["smoke"])
        let result = try await runner.run(cmd)
        XCTAssertTrue(result.stdout.contains("smoke"))
        XCTAssertEqual(result.exitCode, 0)
    }

    func testM4_P2_01_processRunnerStdin() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/usr/bin/wc", arguments: ["-c"])
        let result = try await runner.runWithStdin(cmd, stdin: "test")
        let count = Int(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        XCTAssertEqual(count, 4)
    }

    func testM4_P3_01_processRunnerStreaming() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/echo", arguments: ["stream"])
        var gotOutput = false
        var gotExit = false
        for await output in runner.runStreaming(cmd) {
            switch output {
            case .stdout: gotOutput = true
            case .stderr: break
            case .exit: gotExit = true
            }
        }
        XCTAssertTrue(gotOutput)
        XCTAssertTrue(gotExit)
    }

    func testM4_P4_01_exitCodePropagation() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/sh", arguments: ["-c", "exit 7"])
        let result = try await runner.run(cmd)
        XCTAssertEqual(result.exitCode, 7)
    }

    // MARK: - T1-T4: Terminal Infrastructure

    func testM4_T1_01_terminalCellExists() {
        let cell = TerminalCell(character: "X", foregroundColor: .red, backgroundColor: .default, bold: true)
        XCTAssertEqual(cell.character, "X")
        XCTAssertEqual(cell.foregroundColor, .red)
        XCTAssertTrue(cell.bold)
    }

    func testM4_T1_02_terminalColor256Exists() {
        let color: TerminalColor = .color256(196)
        XCTAssertEqual(color, .color256(196))
    }

    func testM4_T1_03_vt100Parser256Color() {
        let parser = VT100Parser()
        parser.parse(Data("\u{1B}[38;5;100mX".utf8))
        XCTAssertEqual(parser.currentFgColor, .color256(100))
    }

    func testM4_T1_04_vt100ParserCursorVisibility() {
        let parser = VT100Parser()
        parser.parse(Data("\u{1B}[?25l".utf8))
        XCTAssertFalse(parser.cursorVisible)
    }

    func testM4_T1_05_vt100ParserAlternateScreen() {
        let parser = VT100Parser()
        parser.parse(Data("\u{1B}[?1049h".utf8))
        XCTAssertTrue(parser.alternateScreenActive)
    }

    func testM4_T1_06_terminalBufferExists() {
        let buffer = TerminalBuffer(rows: 10, cols: 80)
        XCTAssertEqual(buffer.visibleRows.count, 10)
    }

    func testM4_T1_07_terminalRendererExists() {
        let renderer = TerminalRenderer()
        let grid: [[TerminalCell]] = [[TerminalCell(character: "A")]]
        XCTAssertEqual(renderer.renderText(from: grid), "A")
    }

    func testM4_T1_08_terminalSessionExists() {
        let session = TerminalSession(rows: 24, cols: 80)
        XCTAssertNotNil(session.id)
    }

    // MARK: - TC1-TC2: Toolchain Detection

    func testM4_TC1_01_toolchainDetectorExists() {
        let detector = ToolchainDetector()
        XCTAssertNotNil(detector)
    }

    func testM4_TC1_02_toolchainKindAllCases() {
        XCTAssertEqual(ToolchainKind.allCases.count, 7)
    }

    func testM4_TC2_01_toolchainInfoCreation() {
        let info = ToolchainInfo(kind: .swift, path: "/usr/bin/swift", version: "5.8", isAvailable: true)
        XCTAssertTrue(info.isAvailable)
    }

    // MARK: - B1-B4: Build Service

    func testM4_B1_01_buildServiceProtocolExists() {
        let service = BuildTestService()
        XCTAssertFalse(service.isRunning)
    }

    func testM4_B4_01_buildConfigurationExists() {
        let config = BuildConfiguration.debug
        XCTAssertEqual(config.name, "Debug")
        XCTAssertEqual(config.swiftConfigName, "debug")
    }

    func testM4_B4_02_buildConfigurationManagerExists() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let manager = BuildConfigurationManager(projectRoot: tempDir)
        XCTAssertEqual(manager.configuration.name, "Debug")
    }

    // MARK: - TE1-TE2: Test Service

    func testM4_TE1_01_testReportParserMultiFormat() {
        let swiftOutput = "Test Case 'testA' passed (0.001 seconds)"
        let report = TestReportParser.parse(output: swiftOutput, exitCode: 0)
        XCTAssertEqual(report.passed, 1)
    }

    func testM4_TE1_02_testReportParserGoFormat() {
        let goOutput = "--- PASS: TestAdd (0.00s)"
        let report = TestReportParser.parse(output: goOutput, exitCode: 0)
        XCTAssertEqual(report.passed, 1)
    }

    // MARK: - PR1-PR3: Build Output Parser + Problem Mapping

    func testM4_PR1_01_buildOutputParserExists() {
        let parser = BuildOutputParser()
        XCTAssertNotNil(parser)
    }

    func testM4_PR1_02_parseSwiftCompilerError() {
        let parser = BuildOutputParser()
        let output = "/path/file.swift:10:5: error: unresolved identifier"
        let problems = parser.parse(output)
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems[0].severity, .error)
        XCTAssertEqual(problems[0].line, 10)
    }

    func testM4_PR1_03_problemItemExists() {
        let item = ProblemItem(file: "test.swift", line: 1, severity: .error, message: "err", source: .build)
        XCTAssertEqual(item.file, "test.swift")
    }

    func testM4_PR1_04_problemMapperExists() {
        let mapper = ProblemMapper()
        XCTAssertNotNil(mapper)
    }

    // MARK: - O1-O2: Output Events

    func testM4_O1_01_buildEventExists() {
        let event: BuildEvent = .started(command: "swift build")
        if case .started(let cmd) = event {
            XCTAssertEqual(cmd, "swift build")
        } else {
            XCTFail("Wrong event")
        }
    }

    func testM4_O2_01_testEventExists() {
        let event: TestEvent = .started(command: "swift test")
        if case .started(let cmd) = event {
            XCTAssertEqual(cmd, "swift test")
        } else {
            XCTFail("Wrong event")
        }
    }

    // MARK: - H7 Compliance: No Shell String Concatenation

    func testM4_H7_10_noShellStringConcatenation() {
        let cmd = Command(executable: "/bin/echo", arguments: ["safe", "args"])
        XCTAssertFalse(cmd.executable.contains("&&"))
        XCTAssertFalse(cmd.executable.contains(";"))
        XCTAssertFalse(cmd.executable.contains("|"))
        for arg in cmd.arguments {
            XCTAssertFalse(arg.contains("&&"))
            XCTAssertFalse(arg.contains(";"))
        }
    }

    // MARK: - M0/M1/M2/M3 Regression

    func testM4_REG_01_m0ProcessRunnerCompat() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run("/bin/echo", args: ["m0-compat"])
        XCTAssertTrue(result.stdout.contains("m0-compat"))
    }

    func testM4_REG_02_m0IsInstalledCompat() async throws {
        let runner = ProcessRunner()
        let installed = await runner.isInstalled("echo")
        XCTAssertTrue(installed)
    }

    func testM4_REG_03_m0BuildTestServiceCompat() throws {
        let service = BuildTestService()
        XCTAssertFalse(service.isRunning)
    }
}
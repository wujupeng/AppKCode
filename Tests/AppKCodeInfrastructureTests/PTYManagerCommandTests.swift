import XCTest
@testable import AppKCodeInfrastructure
@testable import AppKCodeShared

final class PTYManagerCommandTests: XCTestCase {
    func testSpawnWithCommand() throws {
        let pty = PTYManager()
        let cmd = Command(executable: "/bin/echo", arguments: ["hello-pty"])
        try pty.spawn(command: cmd)
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertTrue(pty.pid > 0)
        pty.close()
    }

    func testSpawnWithEnvironment() throws {
        let pty = PTYManager()
        let cmd = Command(executable: "/bin/echo", arguments: ["env-test"], environment: ["MY_PTY_TEST": "abc123"])
        try pty.spawn(command: cmd)
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertTrue(pty.pid > 0)
        pty.close()
    }

    func testResizeDoesNotCrash() throws {
        let pty = PTYManager()
        let cmd = Command(executable: "/bin/echo", arguments: ["resize-test"])
        try pty.spawn(command: cmd)
        pty.resize(cols: 80, rows: 24)
        pty.resize(cols: 120, rows: 40)
        Thread.sleep(forTimeInterval: 0.1)
        pty.close()
    }

    func testM0CompatSpawnShell() throws {
        let pty = PTYManager()
        try pty.spawn(shell: "/bin/echo")
        XCTAssertTrue(pty.pid > 0)
        Thread.sleep(forTimeInterval: 0.1)
        pty.close()
    }
}

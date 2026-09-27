import XCTest
@testable import AppKCodeInfrastructure
@testable import AppKCodeShared

final class PTYManagerCommandTests: XCTestCase {
    func testSpawnWithCommand() throws {
        let pty = PTYManager()
        let cmd = Command(executable: "/bin/echo", arguments: ["hello-pty"])
        try pty.spawn(command: cmd)
        Thread.sleep(forTimeInterval: 0.2)
        pty.close()
        XCTAssertTrue(pty.pid > 0)
    }

    func testSpawnWithEnvironment() throws {
        let pty = PTYManager()
        let cmd = Command(executable: "/usr/bin/env", arguments: [], environment: ["MY_PTY_TEST": "abc123"])
        try pty.spawn(command: cmd)
        Thread.sleep(forTimeInterval: 0.2)
        pty.close()
        XCTAssertTrue(pty.pid > 0)
    }

    func testResizeDoesNotCrash() throws {
        let pty = PTYManager()
        let cmd = Command(executable: "/bin/bash", arguments: [])
        try pty.spawn(command: cmd)
        pty.resize(cols: 80, rows: 24)
        pty.resize(cols: 120, rows: 40)
        pty.close()
    }

    func testM0CompatSpawnShell() throws {
        let pty = PTYManager()
        try pty.spawn(shell: "/bin/echo")
        XCTAssertTrue(pty.pid > 0)
        pty.close()
    }

    func testOnExitCallback() throws {
        let pty = PTYManager()
        let expectation = XCTestExpectation(description: "onExit")
        pty.onExit = { code in
            XCTAssertEqual(code, 0)
            expectation.fulfill()
        }
        let cmd = Command(executable: "/bin/echo", arguments: ["test"])
        try pty.spawn(command: cmd)
        wait(for: [expectation], timeout: 5.0)
        pty.close()
    }
}

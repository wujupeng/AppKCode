import Foundation
import AppKCodeShared

public final class PTYManager: @unchecked Sendable {
    public private(set) var masterFD: Int32 = -1
    public private(set) var pid: pid_t = 0
    public private(set) var isAlive: Bool = false
    public private(set) var exitCode: Int32? = nil
    public var onExit: ((Int32) -> Void)? = nil

    public init() {}

    public func spawn(shell: String) throws {
        try spawn(command: Command(executable: shell, arguments: []))
    }

    public func spawn(command: Command) throws {
        var masterFD: Int32 = 0
        let pid = forkpty(&masterFD, nil, nil, nil)
        guard pid >= 0 else {
            throw AppKError.toolExecutionFailed(tool: "forkpty", cause: "fork failed")
        }
        if pid == 0 {
            for (key, value) in command.environment {
                key.withCString { k in
                    value.withCString { v in
                        _ = setenv(k, v, 1)
                    }
                }
            }
            if let cwd = command.workingDirectory {
                _ = cwd.path.withCString { chdir($0) }
            }
            command.executable.withCString { execPath in
                var cArgs: [UnsafeMutablePointer<CChar>?] = []
                cArgs.append(strdup(execPath))
                for arg in command.arguments {
                    cArgs.append(arg.withCString { strdup($0) })
                }
                cArgs.append(nil)
                _ = execvp(execPath, &cArgs)
            }
            exit(1)
        }
        self.masterFD = masterFD
        self.pid = pid
        self.isAlive = true
        self.exitCode = nil

        let capturedOnExit = self.onExit
        DispatchQueue.global().async { [weak self] in
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            let code = (status & 0xFF00) >> 8
            DispatchQueue.main.async {
                self?.exitCode = code
                self?.isAlive = false
                capturedOnExit?(code)
            }
        }
    }

    public func resize(cols: Int, rows: Int) {
        guard masterFD >= 0 else { return }
        var ws = Darwin_winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
        _ = withUnsafePointer(to: &ws) { ptr in
            Darwin_ioctl(masterFD, TIOCSWINSZ, ptr)
        }
    }

    public func read() async -> Data {
        guard masterFD >= 0 else { return Data() }
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let bytesRead = buffer.withUnsafeMutableBufferPointer { ptr in
            Darwin_read(masterFD, ptr.baseAddress, bufferSize)
        }
        if bytesRead > 0 {
            return Data(buffer[0..<bytesRead])
        }
        return Data()
    }

    public func write(_ data: Data) throws {
        guard masterFD >= 0 else { return }
        let bytesWritten = data.withUnsafeBytes { ptr in
            Darwin_write(masterFD, ptr.baseAddress, data.count)
        }
        if bytesWritten < 0 {
            throw AppKError.toolExecutionFailed(tool: "pty_write", cause: "write failed")
        }
    }

    public func writeString(_ string: String) throws {
        try write(Data(string.utf8))
    }

    public func close() {
        if masterFD >= 0 {
            Darwin_close(masterFD)
            masterFD = -1
        }
        if isAlive && pid > 0 {
            kill(pid, SIGTERM)
            DispatchQueue.global().async { [weak self] in
                Thread.sleep(forTimeInterval: 2.0)
                if self?.isAlive == true {
                    kill(self?.pid ?? 0, SIGKILL)
                }
            }
        }
        isAlive = false
    }

    deinit { close() }
}

public struct Darwin_winsize {
    public var ws_row: UInt16
    public var ws_col: UInt16
    public var ws_xpixel: UInt16
    public var ws_ypixel: UInt16
    public init(ws_row: UInt16, ws_col: UInt16, ws_xpixel: UInt16, ws_ypixel: UInt16) {
        self.ws_row = ws_row
        self.ws_col = ws_col
        self.ws_xpixel = ws_xpixel
        self.ws_ypixel = ws_ypixel
    }
}

@_silgen_name("read") private func Darwin_read(_ fd: Int32, _ buf: UnsafeMutableRawPointer?, _ count: Int) -> Int
@_silgen_name("write") private func Darwin_write(_ fd: Int32, _ buf: UnsafeRawPointer?, _ count: Int) -> Int
@_silgen_name("close") private func Darwin_close(_ fd: Int32) -> Int32
@_silgen_name("forkpty") private func forkpty(_ masterFD: UnsafeMutablePointer<Int32>, _ name: UnsafeMutablePointer<CChar>?, _ termp: OpaquePointer?, _ winp: OpaquePointer?) -> pid_t
@_silgen_name("ioctl") private func Darwin_ioctl(_ fd: Int32, _ request: UInt, _ arg: UnsafeRawPointer) -> Int32

private let TIOCSWINSZ: UInt = 0x80087467

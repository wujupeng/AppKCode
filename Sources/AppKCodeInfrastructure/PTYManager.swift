import Foundation
import AppKCodeShared

public final class PTYManager: @unchecked Sendable {
    public private(set) var masterFD: Int32 = -1
    public private(set) var pid: pid_t = 0
    public private(set) var isAlive: Bool = false

    public init() {}

    public func spawn(shell: String) throws {
        var masterFD: Int32 = 0
        let pid = forkpty(&masterFD, nil, nil, nil)
        guard pid >= 0 else {
            throw AppKError.toolExecutionFailed(tool: "forkpty", cause: "fork failed")
        }
        if pid == 0 {
            execlp(shell, shell, nil)
            exit(1)
        }
        self.masterFD = masterFD
        self.pid = pid
        self.isAlive = true
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
        isAlive = false
    }

    deinit { close() }
}

@_silgen_name("read") private func Darwin_read(_ fd: Int32, _ buf: UnsafeMutableRawPointer?, _ count: Int) -> Int
@_silgen_name("write") private func Darwin_write(_ fd: Int32, _ buf: UnsafeRawPointer?, _ count: Int) -> Int
@_silgen_name("close") private func Darwin_close(_ fd: Int32) -> Int32
@_silgen_name("forkpty") private func forkpty(_ masterFD: UnsafeMutablePointer<Int32>, _ name: UnsafeMutablePointer<CChar>?, _ termp: OpaquePointer?, _ winp: OpaquePointer?) -> pid_t
@_silgen_name("execlp") private func execlp(_ file: UnsafePointer<CChar>, _ arg: UnsafePointer<CChar>?, _ args: UnsafePointer<CChar>?) -> Int32
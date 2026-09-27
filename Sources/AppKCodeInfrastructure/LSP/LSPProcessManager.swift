import Foundation

public final class LSPProcessManager: ObservableObject, @unchecked Sendable {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    @Published public private(set) var status: LanguageServerStatus = .notStarted
    @Published public private(set) var restartCount: Int = 0
    @Published public private(set) var lastCrashTime: Date?

    private var executable: String = ""
    private var arguments: [String] = []
    private var workingDirectory: URL?
    private var autoRestart: Bool = true
    private let maxRestarts: Int = 5
    private var lastStartTime: Date?
    private let minRestartInterval: TimeInterval = 3.0
    private let lock = NSLock()

    public init(autoRestart: Bool = true) {
        self.autoRestart = autoRestart
    }

    public func start(executable: String, arguments: [String] = [], workingDirectory: URL? = nil) throws {
        lock.lock()
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        lock.unlock()
        try doStart()
    }

    private func doStart() throws {
        lock.lock()
        guard status != .running else {
            lock.unlock()
            return
        }

        let proc = Process()
        proc.launchPath = executable
        proc.arguments = arguments
        if let wd = workingDirectory {
            proc.currentDirectoryURL = wd
        }

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        proc.terminationHandler = { [weak self] p in
            self?.handleTermination(status: p.terminationStatus)
        }

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        self.status = .starting
        self.lastStartTime = Date()
        lock.unlock()

        do {
            try proc.run()
            lock.lock()
            self.status = .running
            lock.unlock()
        } catch {
            lock.lock()
            self.status = .crashed(restartCount: restartCount + 1)
            self.lastCrashTime = Date()
            self.restartCount += 1
            lock.unlock()
            throw error
        }
    }

    private func handleTermination(status exitStatus: Int) {
        lock.lock()
        let wasRunning = self.status == .running
        self.process = nil
        self.stdinPipe = nil
        self.stdoutPipe = nil
        self.stderrPipe = nil

        if exitStatus != 0 && wasRunning && autoRestart && restartCount < maxRestarts {
            self.status = .crashed(restartCount: restartCount + 1)
            self.lastCrashTime = Date()
            self.restartCount += 1
            let shouldRestart = true
            let exec = self.executable
            let args = self.arguments
            let wd = self.workingDirectory
            let lastStart = self.lastStartTime
            lock.unlock()

            if shouldRestart {
                let delay: TimeInterval
                if let lastStart = lastStart {
                    let elapsed = Date().timeIntervalSince(lastStart)
                    delay = max(0, minRestartInterval - elapsed)
                } else {
                    delay = 0
                }

                DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                    try? self?.doStart()
                }
            }
        } else if exitStatus != 0 && wasRunning {
            self.status = .crashed(restartCount: restartCount)
            self.lastCrashTime = Date()
            lock.unlock()
        } else {
            self.status = .stopped
            lock.unlock()
        }
    }

    public func stop() {
        lock.lock()
        autoRestart = false
        guard let proc = process else {
            status = .stopped
            lock.unlock()
            return
        }
        lock.unlock()

        DispatchQueue.global().async {
            proc.terminate()
        }

        lock.lock()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        status = .stopped
        lock.unlock()
    }

    public func writeToStdin(_ data: Data) throws {
        lock.lock()
        guard let pipe = stdinPipe else {
            lock.unlock()
            throw LSPProcessError.notRunning
        }
        lock.unlock()

        try pipe.fileHandleForWriting.write(contentsOf: data)
    }

    public func readFromStdout() async -> Data? {
        lock.lock()
        guard let pipe = stdoutPipe else {
            lock.unlock()
            return nil
        }
        lock.unlock()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let data = pipe.fileHandleForReading.availableData
                if data.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }

    public func readFromStderr() async -> Data? {
        lock.lock()
        guard let pipe = stderrPipe else {
            lock.unlock()
            return nil
        }
        lock.unlock()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let data = pipe.fileHandleForReading.availableData
                if data.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
}

public enum LSPProcessError: Error, Sendable {
    case notRunning
    case startFailed(String)
    case timeout
}
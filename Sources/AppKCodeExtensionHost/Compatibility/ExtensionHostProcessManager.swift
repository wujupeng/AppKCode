import Foundation
import AppKCodeShared

// MARK: - Extension Host Process Manager Protocol (TASK-007.1)

public protocol ExtensionHostProcessManager: Sendable {
    var hostType: ExtensionHostType { get }
    var state: HostProcessState { get }
    var processID: ProcessID? { get }

    func start(config: ExtensionHostConfig) async throws -> HostProcessHandle
    func stop(timeout: TimeInterval) async throws -> ProcessExitInfo
    func restart(config: ExtensionHostConfig) async throws -> HostProcessHandle
    func monitorState() -> AsyncStream<HostProcessState>
    func sendSignal(_ signal: ProcessSignal) async throws
}

// MARK: - Extension Host Process Manager Impl (TASK-007.2~007.7, H25)

public final class ExtensionHostProcessManagerImpl: ExtensionHostProcessManager, @unchecked Sendable {
    public let hostType: ExtensionHostType
    private let lock = NSLock()
    private var _state: HostProcessState = .notStarted
    private var process: Process?
    private var ipcChannel: StdioIPCChannel?
    private var stateContinuation: AsyncStream<HostProcessState>.Continuation?
    private var crashCount: Int = 0
    private var lastCrashTime: Date?

    public var state: HostProcessState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    public var processID: ProcessID? {
        lock.lock()
        defer { lock.unlock() }
        if case .running(let pid) = _state {
            return pid
        }
        return nil
    }

    public init(hostType: ExtensionHostType) {
        self.hostType = hostType
    }

    public func start(config: ExtensionHostConfig) async throws -> HostProcessHandle {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.runtimePath)

        var args: [String] = []
        switch config.hostType {
        case .vscodeExtensionHost:
            args.append("--max-old-space-size=\(config.memoryLimitMB)")
            args.append(config.hostScriptPath)
        case .jetbrainsPluginHost:
            args.append("-Xmx\(config.memoryLimitMB)m")
            args.append("-jar")
            args.append(config.hostScriptPath)
        }
        args.append(contentsOf: config.extraArgs)
        process.arguments = args

        let ipcChannel = StdioIPCChannel(process: process)
        try await ipcChannel.connect()

        lock.lock()
        _state = .starting
        emitState()
        lock.unlock()

        do {
            try process.run()
        } catch {
            lock.lock()
            _state = .crashed(exitCode: -1, timestamp: ISO8601Timestamp())
            emitState()
            lock.unlock()
            throw ExtensionHostError.startupTimeout
        }

        let pid = ProcessID(Int32(process.processIdentifier))

        lock.lock()
        self.process = process
        self.ipcChannel = ipcChannel
        _state = .running(pid: pid)
        emitState()
        lock.unlock()

        process.terminationHandler = { [weak self] proc in
            guard let self = self else { return }
            self.lock.lock()
            let exitCode = Int32(proc.terminationStatus)
            self._state = .crashed(exitCode: exitCode, timestamp: ISO8601Timestamp())
            self.crashCount += 1
            self.lastCrashTime = Date()
            self.emitState()
            self.lock.unlock()
        }

        return HostProcessHandle(
            processID: pid,
            ipcChannel: config.ipcChannel
        )
    }

    public func stop(timeout: TimeInterval) async throws -> ProcessExitInfo {
        lock.lock()
        let currentProcess = process
        let currentChannel = ipcChannel
        lock.unlock()

        guard let proc = currentProcess else {
            return ProcessExitInfo(exitCode: 0)
        }

        if let channel = currentChannel {
            try? await channel.sendNotification("deactivate", params: nil)
        }

        let result: ProcessExitInfo = await withCheckedContinuation { continuation in
            let workItem = DispatchWorkItem {
                proc.terminate()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: workItem)

            proc.terminationHandler = { p in
                workItem.cancel()
                continuation.resume(returning: ProcessExitInfo(exitCode: Int32(p.terminationStatus)))
            }
        }

        lock.lock()
        if let channel = currentChannel {
            _ = try? await channel.disconnect()
        }
        self.process = nil
        self.ipcChannel = nil
        _state = .stopped(exitCode: result.exitCode)
        emitState()
        lock.unlock()

        return result
    }

    public func restart(config: ExtensionHostConfig) async throws -> HostProcessHandle {
        _ = try await stop(timeout: 5.0)
        return try await start(config: config)
    }

    public func monitorState() -> AsyncStream<HostProcessState> {
        AsyncStream { continuation in
            self.lock.lock()
            self.stateContinuation = continuation
            self.lock.unlock()
        }
    }

    public func sendSignal(_ signal: ProcessSignal) async throws {
        lock.lock()
        let proc = process
        lock.unlock()

        guard let proc = proc else { return }

        switch signal {
        case .terminate:
            proc.terminate()
        case .kill:
            kill(proc.processIdentifier, SIGKILL)
        case .interrupt:
            kill(proc.processIdentifier, SIGINT)
        }
    }

    private func emitState() {
        stateContinuation?.yield(_state)
    }
}
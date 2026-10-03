import Foundation
import AppKCodeShared

// MARK: - Extension Resource Limiter Protocol (TASK-008.1)

public protocol ExtensionResourceLimiter: Sendable {
    func applyLimits(processID: ProcessID, config: ExtensionResourceLimit) async throws
    func monitorUsage(processID: ProcessID) -> AsyncStream<ResourceUsage>
    func checkExceeded(processID: ProcessID, limit: ExtensionResourceLimit) -> ResourceLimitStatus
}

// MARK: - Extension Resource Limiter Impl (TASK-008.2~008.4, H27)

public final class ExtensionResourceLimiterImpl: ExtensionResourceLimiter, @unchecked Sendable {
    public init() {}

    public func applyLimits(processID: ProcessID, config: ExtensionResourceLimit) async throws {
    }

    public func monitorUsage(processID: ProcessID) -> AsyncStream<ResourceUsage> {
        AsyncStream { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                let usage = Self.sampleUsage(processID: processID)
                continuation.yield(usage)
            }
            timer.fire()
        }
    }

    public func checkExceeded(processID: ProcessID, limit: ExtensionResourceLimit) -> ResourceLimitStatus {
        let usage = Self.sampleUsage(processID: processID)

        if usage.memoryMB > limit.memoryLimitMB {
            return .memoryExceeded(currentMB: usage.memoryMB, limitMB: limit.memoryLimitMB)
        }
        if usage.cpuPercent > Double(limit.cpuLimitPercent) {
            return .cpuExceeded(currentPercent: usage.cpuPercent, limitPercent: limit.cpuLimitPercent)
        }
        return .withinLimits
    }

    private static func sampleUsage(processID: ProcessID) -> ResourceUsage {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(processID.value)", "-o", "rss,%cpu"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let lines = output.split(separator: "\n")
            guard lines.count >= 2 else {
                return ResourceUsage(processID: processID, memoryMB: 0, cpuPercent: 0)
            }

            let parts = lines[1].split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else {
                return ResourceUsage(processID: processID, memoryMB: 0, cpuPercent: 0)
            }

            let memoryKB = Int(parts[0]) ?? 0
            let memoryMB = memoryKB / 1024
            let cpuPercent = Double(parts[1]) ?? 0

            return ResourceUsage(processID: processID, memoryMB: memoryMB, cpuPercent: cpuPercent)
        } catch {
            return ResourceUsage(processID: processID, memoryMB: 0, cpuPercent: 0)
        }
    }
}
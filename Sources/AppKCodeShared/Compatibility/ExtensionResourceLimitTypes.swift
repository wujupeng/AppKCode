import Foundation

// MARK: - Extension Resource Limit (TASK-003.1, H27)

public struct ExtensionResourceLimit: Sendable, Codable, Equatable {
    public let hostType: ExtensionHostType
    public let memoryLimitMB: Int
    public let cpuLimitPercent: Int
    public let crashLimit60s: Int
    public let restartTimeoutMS: Int

    public init(
        hostType: ExtensionHostType,
        memoryLimitMB: Int,
        cpuLimitPercent: Int,
        crashLimit60s: Int = 3,
        restartTimeoutMS: Int = 3000
    ) {
        self.hostType = hostType
        self.memoryLimitMB = memoryLimitMB
        self.cpuLimitPercent = cpuLimitPercent
        self.crashLimit60s = crashLimit60s
        self.restartTimeoutMS = restartTimeoutMS
    }

    public static func defaultFor(_ hostType: ExtensionHostType) -> ExtensionResourceLimit {
        switch hostType {
        case .vscodeExtensionHost:
            return ExtensionResourceLimit(
                hostType: hostType,
                memoryLimitMB: 512,
                cpuLimitPercent: 80
            )
        case .jetbrainsPluginHost:
            return ExtensionResourceLimit(
                hostType: hostType,
                memoryLimitMB: 2048,
                cpuLimitPercent: 80
            )
        }
    }
}

// MARK: - Resource Usage (TASK-003.2)

public struct ResourceUsage: Sendable, Codable, Equatable {
    public let processID: ProcessID
    public let memoryMB: Int
    public let cpuPercent: Double
    public let timestamp: ISO8601Timestamp

    public init(
        processID: ProcessID,
        memoryMB: Int,
        cpuPercent: Double,
        timestamp: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.processID = processID
        self.memoryMB = memoryMB
        self.cpuPercent = cpuPercent
        self.timestamp = timestamp
    }
}

// MARK: - Resource Limit Status (TASK-003.3)

public enum ResourceLimitStatus: Sendable, Codable, Equatable {
    case withinLimits
    case memoryExceeded(currentMB: Int, limitMB: Int)
    case cpuExceeded(currentPercent: Double, limitPercent: Int)
}
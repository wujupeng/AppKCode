import Foundation
import CryptoKit
import AppKCodeShared

// MARK: - Audit Log Store (TASK-008, H14)

public final class AuditLogStore: @unchecked Sendable {
    private let auditRootDirectory: URL
    private let queue = DispatchQueue(label: "appk.agent.audit", qos: .utility)

    public init(auditRootDirectory: URL? = nil) {
        if let dir = auditRootDirectory {
            self.auditRootDirectory = dir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.auditRootDirectory = home.appendingPathComponent(".appk/agent-audit")
        }
        try? FileManager.default.createDirectory(at: self.auditRootDirectory, withIntermediateDirectories: true)
    }

    public static func computeSHA256(_ record: AgentAuditRecord) -> String {
        let payload: [String: Any] = [
            "id": record.id.rawValue,
            "timestamp": record.timestamp.rawValue,
            "sessionID": record.sessionID.rawValue,
            "tool": record.tool.rawValue,
            "target": String(describing: record.target),
            "approval": String(describing: record.approval),
            "result": String(describing: record.result),
            "error": record.error ?? ""
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return ""
        }
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    public func append(_ record: AgentAuditRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [auditRootDirectory] in
                let dateStr = String(record.timestamp.rawValue.prefix(10))
                let fileURL = auditRootDirectory.appendingPathComponent("\(dateStr).jsonl")

                let encoder = JSONEncoder()
                guard var data = try? encoder.encode(record) else {
                    continuation.resume(throwing: AppKError.encodingFailed(detail: "audit record"))
                    return
                }
                data.append(0x0A)

                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try? data.write(to: fileURL)
                }
                continuation.resume()
            }
        }
    }

    public func query(_ filter: AuditFilter) async throws -> [AgentAuditRecord] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: auditRootDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        let decoder = JSONDecoder()
        var results: [AgentAuditRecord] = []

        for file in files where file.pathExtension == "jsonl" {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let data = String(line).data(using: .utf8),
                      let record = try? decoder.decode(AgentAuditRecord.self, from: data) else { continue }

                if let filterSession = filter.sessionID, filterSession != record.sessionID { continue }
                if let filterTool = filter.tool, filterTool != record.tool { continue }
                if let filterResult = filter.result, filterResult != record.result { continue }
                if let timeRange = filter.timeRange {
                    if record.timestamp < timeRange.from || record.timestamp > timeRange.to { continue }
                }

                results.append(record)
            }
        }

        return results.sorted { $0.timestamp < $1.timestamp }
    }

    public func verifyIntegrity(file: URL) async throws -> Bool {
        guard FileManager.default.fileExists(atPath: file.path) else {
            return true
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let decoder = JSONDecoder()

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = String(line).data(using: .utf8),
                  let record = try? decoder.decode(AgentAuditRecord.self, from: data) else {
                return false
            }

            let computedHash = Self.computeSHA256(record)
            if computedHash != record.sha256 {
                return false
            }
        }

        return true
    }
}
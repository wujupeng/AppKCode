import Foundation
import AppKCodeShared

public final class JSONLAuditStore: InfraAuditStore, @unchecked Sendable {
    private let auditDirectory: URL
    private let queue = DispatchQueue(label: "appk.audit", qos: .utility)

    public init(auditDirectory: URL? = nil) {
        if let dir = auditDirectory {
            self.auditDirectory = dir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.auditDirectory = home.appendingPathComponent(".appk/audit")
        }
        try? FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
    }

    public func append(_ record: AuditRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [auditDirectory] in
                let dateStr = String(record.timestamp.rawValue.prefix(10))
                let fileURL = auditDirectory.appendingPathComponent("\(dateStr).jsonl")
                let entry: [String: Any] = [
                    "timestamp": record.timestamp.rawValue,
                    "operation": record.operation,
                    "decision": String(describing: record.decision),
                    "decidedBy": record.decidedBy.rawValue,
                    "sha256": record.sha256,
                    "sessionID": record.sessionID.rawValue
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: entry),
                      let line = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: AppKError.encodingFailed(detail: "audit record"))
                    return
                }
                let lineToWrite = line + "\n"
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(Data(lineToWrite.utf8))
                    handle.closeFile()
                } else {
                    try? lineToWrite.write(to: fileURL, atomically: true, encoding: .utf8)
                }
                continuation.resume()
            }
        }
    }

    public func query(filter: AuditQueryFilter) async throws -> [AuditRecord] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: auditDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        var results: [AuditRecord] = []
        for file in files where file.pathExtension == "jsonl" {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n") {
                guard let data = line.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                guard let timestamp = dict["timestamp"] as? String,
                      let operation = dict["operation"] as? String,
                      let decisionStr = dict["decision"] as? String,
                      let decidedBy = dict["decidedBy"] as? String,
                      let sha256 = dict["sha256"] as? String,
                      let sessionID = dict["sessionID"] as? String else { continue }
                if let filterSession = filter.sessionID, filterSession.rawValue != sessionID { continue }
                let decision: ApprovalDecision = {
                    switch decisionStr {
                    case "allow": return .allow
                    case "reject": return .reject
                    case "timeout": return .timeout
                    default: return .pending
                    }
                }()
                results.append(AuditRecord(
                    timestamp: ISO8601Timestamp(rawValue: timestamp),
                    operation: operation,
                    decision: decision,
                    decidedBy: UserID(decidedBy),
                    sha256: sha256,
                    sessionID: AgentSessionID(sessionID)
                ))
            }
        }
        return results.sorted { $0.timestamp < $1.timestamp }
    }
}
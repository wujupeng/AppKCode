import Foundation
import AppKCodeShared

public final class JSONLEvidenceStore: InfraEvidenceStore, @unchecked Sendable {
    private let evidenceDirectory: URL
    private let queue = DispatchQueue(label: "appk.evidence", qos: .utility)

    public init(evidenceDirectory: URL? = nil) {
        if let dir = evidenceDirectory {
            self.evidenceDirectory = dir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.evidenceDirectory = home.appendingPathComponent(".appk/evidence")
        }
        try? FileManager.default.createDirectory(at: self.evidenceDirectory, withIntermediateDirectories: true)
    }

    public func append(_ record: EvidenceRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [evidenceDirectory] in
                let fileURL = evidenceDirectory.appendingPathComponent("\(record.sessionID.rawValue).jsonl")
                let entry: [String: Any] = [
                    "evidenceID": record.evidenceID,
                    "sessionID": record.sessionID.rawValue,
                    "kind": String(describing: record.kind),
                    "content": record.content,
                    "contentHash": record.contentHash,
                    "capturedAt": record.capturedAt.rawValue
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: entry),
                      let line = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: AppKError.encodingFailed(detail: "evidence record"))
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

    public func chain(for session: AgentSessionID) async throws -> EvidenceChain {
        let fileURL = evidenceDirectory.appendingPathComponent("\(session.rawValue).jsonl")
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return EvidenceChain(sessionID: session, records: [])
        }
        var records: [EvidenceRecord] = []
        for line in content.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard let evidenceID = dict["evidenceID"] as? String,
                  let kindStr = dict["kind"] as? String,
                  let contentStr = dict["content"] as? String,
                  let contentHash = dict["contentHash"] as? String,
                  let capturedAt = dict["capturedAt"] as? String else { continue }
            let kind: EvidenceKind = {
                switch kindStr {
                case "commandOutput": return .commandOutput
                case "fileContent": return .fileContent
                case "testReport": return .testReport
                case "commitHash": return .commitHash
                case "modelResponse": return .modelResponse
                case "approvalDecision": return .approvalDecision
                default: return .commandOutput
                }
            }()
            records.append(EvidenceRecord(
                evidenceID: evidenceID,
                sessionID: session,
                kind: kind,
                content: contentStr,
                contentHash: contentHash,
                capturedAt: ISO8601Timestamp(rawValue: capturedAt)
            ))
        }
        return EvidenceChain(sessionID: session, records: records.sorted { $0.capturedAt < $1.capturedAt })
    }
}
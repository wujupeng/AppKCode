import Foundation
import AppKCodeShared

public final class StructuredLogger: @unchecked Sendable {
    private let logDirectory: URL
    private let queue = DispatchQueue(label: "appk.logger", qos: .utility)

    public init(logDirectory: URL? = nil) {
        if let dir = logDirectory {
            self.logDirectory = dir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.logDirectory = home.appendingPathComponent(".appk/logs")
        }
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    public func log(level: LogLevel, bundle: String, message: String, traceID: TraceID = TraceID(), spanID: SpanID = SpanID()) {
        queue.async { [logDirectory] in
            let timestamp = ISO8601Timestamp()
            let entry: [String: String] = [
                "timestamp": timestamp.rawValue,
                "level": level.rawValue,
                "bundle": bundle,
                "message": message,
                "trace_id": traceID.rawValue.uuidString,
                "span_id": spanID.rawValue.uuidString
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: entry),
                  let line = String(data: data, encoding: .utf8) else { return }
            let dateStr = String(timestamp.rawValue.prefix(10))
            let fileURL = logDirectory.appendingPathComponent("\(dateStr).jsonl")
            let lineToWrite = line + "\n"
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(Data(lineToWrite.utf8))
                handle.closeFile()
            } else {
                try? lineToWrite.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
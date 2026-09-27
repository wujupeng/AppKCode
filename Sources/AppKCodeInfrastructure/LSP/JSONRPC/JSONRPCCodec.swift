import Foundation

public final class JSONRPCCodec: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()
    private let headerSeparator = "\r\n\r\n".data(using: .utf8)!
    private let contentLengthPrefix = "Content-Length: "

    public init() {}

    public func encode(_ message: JSONRPCMessage) throws -> Data {
        let jsonBody = try message.encode()
        let header = "\(contentLengthPrefix)\(jsonBody.count)\r\n\r\n".data(using: .utf8)!
        return header + jsonBody
    }

    public func decode(_ data: Data) -> [JSONRPCMessage] {
        lock.lock()
        buffer.append(data)
        var messages: [JSONRPCMessage] = []

        while true {
            guard let (message, consumed) = decodeOne() else {
                break
            }
            messages.append(message)
            buffer.removeFirst(consumed)
        }

        lock.unlock()
        return messages
    }

    public func decodeAll() -> [JSONRPCMessage] {
        lock.lock()
        var messages: [JSONRPCMessage] = []
        while true {
            guard let (message, consumed) = decodeOne() else {
                break
            }
            messages.append(message)
            buffer.removeFirst(consumed)
        }
        lock.unlock()
        return messages
    }

    private func decodeOne() -> (JSONRPCMessage, Int)? {
        guard let separatorRange = buffer.range(of: headerSeparator) else {
            return nil
        }

        let headerData = buffer[0..<separatorRange.lowerBound]
        guard let header = String(data: headerData, encoding: .utf8) else {
            return nil
        }

        var contentLength: Int? = nil
        for line in header.components(separatedBy: "\r\n") {
            if line.hasPrefix(contentLengthPrefix) {
                let lengthStr = line.dropFirst(contentLengthPrefix.count)
                contentLength = Int(lengthStr)
            }
        }

        guard let length = contentLength else {
            return nil
        }

        let bodyStart = separatorRange.upperBound
        let bodyEnd = bodyStart + length

        guard buffer.count >= bodyEnd else {
            return nil
        }

        let bodyData = buffer[bodyStart..<bodyEnd]
        guard let message = parseMessage(bodyData) else {
            return nil
        }

        let totalConsumed = bodyEnd
        return (message, totalConsumed)
    }

    private func parseMessage(_ data: Data) -> JSONRPCMessage? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if json["method"] != nil {
            if json["id"] != nil {
                let decoder = JSONDecoder()
                if let request = try? decoder.decode(JSONRPCRequest.self, from: data) {
                    return .request(request)
                }
            } else {
                let decoder = JSONDecoder()
                if let notification = try? decoder.decode(JSONRPCNotification.self, from: data) {
                    return .notification(notification)
                }
            }
        } else if json["result"] != nil || json["error"] != nil {
            let decoder = JSONDecoder()
            if let response = try? decoder.decode(JSONRPCResponse.self, from: data) {
                return .response(response)
            }
        }

        return nil
    }

    public func clearBuffer() {
        lock.lock()
        buffer.removeAll()
        lock.unlock()
    }
}
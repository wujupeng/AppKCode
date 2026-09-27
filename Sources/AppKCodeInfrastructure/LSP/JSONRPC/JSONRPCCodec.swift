import Foundation

public final class JSONRPCCodec: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()
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
            if consumed > 0 && consumed <= buffer.count {
                buffer.removeFirst(consumed)
            } else {
                break
            }
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
            if consumed > 0 && consumed <= buffer.count {
                buffer.removeFirst(consumed)
            } else {
                break
            }
        }
        lock.unlock()
        return messages
    }

    private func decodeOne() -> (JSONRPCMessage, Int)? {
        let bytes = [UInt8](buffer)
        guard let sepPos = findHeaderSeparator(in: bytes) else {
            return nil
        }

        let headerBytes = Array(bytes[0..<sepPos])
        guard let header = String(bytes: headerBytes, encoding: .utf8) else {
            return nil
        }

        var contentLength: Int? = nil
        for line in header.components(separatedBy: "\r\n") {
            if line.hasPrefix(contentLengthPrefix) {
                let lengthStr = line.dropFirst(contentLengthPrefix.count)
                contentLength = Int(lengthStr)
            }
        }

        guard let length = contentLength, length > 0 else {
            return nil
        }

        let bodyStart = sepPos + 4
        let bodyEnd = bodyStart + length

        guard bytes.count >= bodyEnd else {
            return nil
        }

        let bodyBytes = Array(bytes[bodyStart..<bodyEnd])
        let bodyData = Data(bodyBytes)
        guard let message = parseMessage(bodyData) else {
            return nil
        }

        return (message, bodyEnd)
    }

    private func findHeaderSeparator(in bytes: [UInt8]) -> Int? {
        let n = bytes.count
        if n < 4 { return nil }
        for i in 0...(n - 4) {
            if bytes[i] == 0x0D && bytes[i+1] == 0x0A && bytes[i+2] == 0x0D && bytes[i+3] == 0x0A {
                return i
            }
        }
        return nil
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

import Foundation

public enum JSONRPCMessage: Sendable {
    case request(JSONRPCRequest)
    case response(JSONRPCResponse)
    case notification(JSONRPCNotification)

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        switch self {
        case .request(let req):
            return try encoder.encode(req)
        case .response(let res):
            return try encoder.encode(res)
        case .notification(let notif):
            return try encoder.encode(notif)
        }
    }

    public var method: String? {
        switch self {
        case .request(let req): return req.method
        case .notification(let notif): return notif.method
        case .response: return nil
        }
    }
}
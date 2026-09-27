import Foundation

public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int64
    public let result: AnyCodable?
    public let error: JSONRPCError?

    public init(id: Int64, result: AnyCodable? = nil, error: JSONRPCError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, result, error
    }
}
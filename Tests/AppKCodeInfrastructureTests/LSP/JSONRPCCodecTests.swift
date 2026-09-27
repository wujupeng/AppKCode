import XCTest
@testable import AppKCodeInfrastructure

final class JSONRPCCodecTests: XCTestCase {
    func testEncodeRequest() throws {
        let codec = JSONRPCCodec()
        let request = JSONRPCRequest(id: 1, method: "initialize", params: AnyCodable(["key": "value"]))
        let data = try codec.encode(.request(request))

        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("Content-Length:"))
        XCTAssertTrue(str.contains("\"method\":\"initialize\""))
        XCTAssertTrue(str.contains("\"id\":1"))
        XCTAssertTrue(str.contains("\"jsonrpc\":\"2.0\""))
    }

    func testEncodeNotification() throws {
        let codec = JSONRPCCodec()
        let notif = JSONRPCNotification(method: "initialized", params: nil)
        let data = try codec.encode(.notification(notif))

        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("Content-Length:"))
        XCTAssertTrue(str.contains("\"method\":\"initialized\""))
        XCTAssertFalse(str.contains("\"id\""))
    }

    func testEncodeResponse() throws {
        let codec = JSONRPCCodec()
        let response = JSONRPCResponse(id: 1, result: AnyCodable("ok"))
        let data = try codec.encode(.response(response))

        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("\"id\":1"))
        XCTAssertTrue(str.contains("\"result\":\"ok\""))
    }

    func testDecodeRequest() throws {
        let codec = JSONRPCCodec()
        let original = JSONRPCRequest(id: 42, method: "test", params: AnyCodable(["a": 1]))
        let encoded = try codec.encode(.request(original))

        let messages = codec.decode(encoded)
        XCTAssertEqual(messages.count, 1)

        if case .request(let req) = messages.first {
            XCTAssertEqual(req.id, 42)
            XCTAssertEqual(req.method, "test")
        } else {
            XCTFail("Expected request")
        }
    }

    func testDecodeMultipleMessages() throws {
        let codec = JSONRPCCodec()
        let req1 = JSONRPCRequest(id: 1, method: "foo")
        let req2 = JSONRPCRequest(id: 2, method: "bar")
        let notif = JSONRPCNotification(method: "baz")

        var combined = Data()
        combined.append(try codec.encode(.request(req1)))
        combined.append(try codec.encode(.request(req2)))
        combined.append(try codec.encode(.notification(notif)))

        let messages = codec.decode(combined)
        XCTAssertEqual(messages.count, 3)
    }

    func testIncompleteMessageBuffered() throws {
        let codec = JSONRPCCodec()
        let request = JSONRPCRequest(id: 1, method: "test")
        let encoded = try codec.encode(.request(request))

        let half = encoded.prefix(encoded.count / 2)
        let messages = codec.decode(Data(half))
        XCTAssertEqual(messages.count, 0)

        let rest = encoded.suffix(encoded.count - encoded.count / 2)
        let moreMessages = codec.decode(Data(rest))
        XCTAssertEqual(moreMessages.count, 1)
    }

    func testAnyCodableNull() {
        let val = AnyCodable(null: ())
        let encoder = JSONEncoder()
        let data = try! encoder.encode(val)
        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertEqual(str, "null")
    }

    func testAnyCodableString() {
        let val = AnyCodable("hello")
        let encoder = JSONEncoder()
        let data = try! encoder.encode(val)
        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertEqual(str, "\"hello\"")
    }

    func testAnyCodableInt() {
        let val = AnyCodable(Int64(42))
        let encoder = JSONEncoder()
        let data = try! encoder.encode(val)
        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertEqual(str, "42")
    }

    func testAnyCodableArray() {
        let val = AnyCodable([AnyCodable("a"), AnyCodable("b")])
        let encoder = JSONEncoder()
        let data = try! encoder.encode(val)
        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("a"))
        XCTAssertTrue(str.contains("b"))
    }

    func testJSONRPCErrorCodes() {
        XCTAssertEqual(JSONRPCError.parseError.code, -32700)
        XCTAssertEqual(JSONRPCError.invalidRequest.code, -32600)
        XCTAssertEqual(JSONRPCError.methodNotFound.code, -32601)
        XCTAssertEqual(JSONRPCError.invalidParams.code, -32602)
        XCTAssertEqual(JSONRPCError.internalError.code, -32603)
    }
}
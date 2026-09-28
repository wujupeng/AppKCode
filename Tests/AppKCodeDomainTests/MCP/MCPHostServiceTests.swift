import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeInfrastructure

final class MCPHostServiceTests: XCTestCase {
    func testMCPServerConfigCreation() {
        let config = MCPServerConfig(
            name: "test-server",
            transport: .stdio(command: "/usr/bin/echo", args: [], env: nil)
        )
        XCTAssertEqual(config.name, "test-server")
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.autoDiscoverTools)
    }

    func testMCPTransportTypes() {
        let stdio = MCPTransport.stdio(command: "cmd", args: ["arg1"], env: ["KEY": "VALUE"])
        let http = MCPTransport.http(endpoint: URL(string: "http://localhost:8080")!)
        let sse = MCPTransport.sse(endpoint: URL(string: "http://localhost:8080/sse")!)

        if case .stdio(let cmd, let args, let env) = stdio {
            XCTAssertEqual(cmd, "cmd")
            XCTAssertEqual(args, ["arg1"])
            XCTAssertEqual(env?["KEY"], "VALUE")
        } else {
            XCTFail("Expected stdio transport")
        }

        if case .http(let url) = http {
            XCTAssertEqual(url.host, "localhost")
        } else {
            XCTFail("Expected http transport")
        }

        if case .sse(let url) = sse {
            XCTAssertEqual(url.path, "/sse")
        } else {
            XCTFail("Expected sse transport")
        }
    }

    func testMCPConnectionStates() {
        let states: [MCPConnectionState] = [
            .disconnected,
            .connecting,
            .connected,
            .disconnectedUnexpectedly(reason: "crash"),
            .failed(error: "timeout")
        ]
        XCTAssertEqual(states.count, 5)
    }

    func testMCPToolDescriptor() {
        let descriptor = MCPToolDescriptor(
            name: "search",
            description: "Search tool",
            inputSchema: JSONSchema(type: "object"),
            annotations: MCPToolAnnotations(readOnlyHint: true, destructiveHint: false)
        )
        XCTAssertEqual(descriptor.name, "search")
        XCTAssertEqual(descriptor.annotations?.readOnlyHint, true)
    }

    func testMCPContentTypes() {
        let text = MCPContent.text("hello")
        let image = MCPContent.image(data: Data([0x89]), mimeType: "image/png")
        let resource = MCPContent.resource(uri: "file:///test")

        if case .text(let t) = text { XCTAssertEqual(t, "hello") } else { XCTFail() }
        if case .image(let data, let mime) = image { XCTAssertEqual(mime, "image/png"); XCTAssertEqual(data, Data([0x89])) } else { XCTFail() }
        if case .resource(let uri) = resource { XCTAssertEqual(uri, "file:///test") } else { XCTFail() }
    }

    func testMCPErrorCodes() {
        XCTAssertEqual(MCPErrorCode.parseError.rawValue, -32700)
        XCTAssertEqual(MCPErrorCode.invalidRequest.rawValue, -32600)
        XCTAssertEqual(MCPErrorCode.methodNotFound.rawValue, -32601)
        XCTAssertEqual(MCPErrorCode.invalidParams.rawValue, -32602)
        XCTAssertEqual(MCPErrorCode.internalError.rawValue, -32603)
    }

    func testAnyCodableValue() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let intValue = AnyCodableValue.int(42)
        let intData = try encoder.encode(intValue)
        let decodedInt = try decoder.decode(AnyCodableValue.self, from: intData)
        XCTAssertEqual(decodedInt, .int(42))

        let stringValue = AnyCodableValue.string("hello")
        let stringData = try encoder.encode(stringValue)
        let decodedString = try decoder.decode(AnyCodableValue.self, from: stringData)
        XCTAssertEqual(decodedString, .string("hello"))

        let nullValue = AnyCodableValue.null
        let nullData = try encoder.encode(nullValue)
        let decodedNull = try decoder.decode(AnyCodableValue.self, from: nullData)
        XCTAssertEqual(decodedNull, .null)
    }
}

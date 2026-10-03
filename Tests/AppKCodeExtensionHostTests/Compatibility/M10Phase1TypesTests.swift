import XCTest
@testable import AppKCodeExtensionHost
import AppKCodeShared

final class M10Phase1TypesTests: XCTestCase {

    func test_StreamingCapabilityResult_creation() {
        let result = StreamingCapabilityResult(
            chunkIndex: 0,
            chunkData: .string("test"),
            isFinal: false
        )
        XCTAssertEqual(result.chunkIndex, 0)
        XCTAssertEqual(result.chunkData, .string("test"))
        XCTAssertFalse(result.isFinal)
        XCTAssertNil(result.error)
    }

    func test_StreamingCapabilityResult_final() {
        let result = StreamingCapabilityResult(
            chunkIndex: 5,
            chunkData: .null,
            isFinal: true,
            totalChunks: 6
        )
        XCTAssertTrue(result.isFinal)
        XCTAssertEqual(result.totalChunks, 6)
    }

    func test_StreamingError_creation() {
        let error = StreamingError(code: 1, message: "test error", recoverable: true)
        XCTAssertEqual(error.code, 1)
        XCTAssertTrue(error.recoverable)
    }

    func test_IPCMessage_request() {
        let msg = IPCMessage(id: 1, method: "test.method", params: .string("param"))
        XCTAssertTrue(msg.isRequest)
        XCTAssertFalse(msg.isResponse)
        XCTAssertFalse(msg.isNotification)
    }

    func test_IPCMessage_response() {
        let msg = IPCMessage(id: 1, result: .string("result"))
        XCTAssertFalse(msg.isRequest)
        XCTAssertTrue(msg.isResponse)
        XCTAssertFalse(msg.isNotification)
    }

    func test_IPCMessage_notification() {
        let msg = IPCMessage(method: "notify", params: .null)
        XCTAssertFalse(msg.isRequest)
        XCTAssertFalse(msg.isResponse)
        XCTAssertTrue(msg.isNotification)
    }

    func test_IPCError_standardCodes() {
        XCTAssertEqual(IPCError.parseError.code, -32700)
        XCTAssertEqual(IPCError.invalidRequest.code, -32600)
        XCTAssertEqual(IPCError.methodNotFound.code, -32601)
        XCTAssertEqual(IPCError.invalidParams.code, -32602)
        XCTAssertEqual(IPCError.internalError.code, -32603)
    }

    func test_IPCChannelDescriptor_stdio() {
        let desc = IPCChannelDescriptor(kind: .stdio)
        XCTAssertEqual(desc.kind, .stdio)
        XCTAssertNil(desc.path)
    }

    func test_IPCChannelDescriptor_namedPipe() {
        let desc = IPCChannelDescriptor(kind: .namedPipe, path: "/tmp/test.pipe")
        XCTAssertEqual(desc.kind, .namedPipe)
        XCTAssertEqual(desc.path, "/tmp/test.pipe")
    }

    func test_FileTransferRef_creation() {
        let ref = FileTransferRef(path: "/tmp/test", size: 1024, sha256: "abc123")
        XCTAssertEqual(ref.path, "/tmp/test")
        XCTAssertEqual(ref.size, 1024)
        XCTAssertEqual(ref.sha256, "abc123")
    }

    func test_ExtensionHostType_values() {
        XCTAssertEqual(ExtensionHostType.vscodeExtensionHost.rawValue, "vscodeExtensionHost")
        XCTAssertEqual(ExtensionHostType.jetbrainsPluginHost.rawValue, "jetbrainsPluginHost")
    }

    func test_HostProcessState_notStarted() {
        let state: HostProcessState = .notStarted
        if case .notStarted = state {} else { XCTFail() }
    }

    func test_HostProcessState_running() {
        let pid = ProcessID(12345)
        let state: HostProcessState = .running(pid: pid)
        if case .running(let p) = state {
            XCTAssertEqual(p.value, 12345)
        } else {
            XCTFail()
        }
    }

    func test_ExtensionHostConfig_creation() {
        let config = ExtensionHostConfig(
            hostType: .vscodeExtensionHost,
            runtimePath: "/usr/local/bin/node",
            runtimeVersion: SemVer(20, 0, 0),
            memoryLimitMB: 512,
            cpuLimitPercent: 80,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: "/tmp/extension-host.js"
        )
        XCTAssertEqual(config.hostType, .vscodeExtensionHost)
        XCTAssertEqual(config.memoryLimitMB, 512)
    }

    func test_ExtensionResourceLimit_default_vscode() {
        let limit = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        XCTAssertEqual(limit.memoryLimitMB, 512)
        XCTAssertEqual(limit.cpuLimitPercent, 80)
        XCTAssertEqual(limit.crashLimit60s, 3)
        XCTAssertEqual(limit.restartTimeoutMS, 3000)
    }

    func test_ExtensionResourceLimit_default_jetbrains() {
        let limit = ExtensionResourceLimit.defaultFor(.jetbrainsPluginHost)
        XCTAssertEqual(limit.memoryLimitMB, 2048)
        XCTAssertEqual(limit.cpuLimitPercent, 80)
    }

    func test_ResourceUsage_creation() {
        let usage = ResourceUsage(
            processID: ProcessID(1),
            memoryMB: 100,
            cpuPercent: 50.0
        )
        XCTAssertEqual(usage.memoryMB, 100)
        XCTAssertEqual(usage.cpuPercent, 50.0)
    }

    func test_ResourceLimitStatus_withinLimits() {
        let status: ResourceLimitStatus = .withinLimits
        if case .withinLimits = status {} else { XCTFail() }
    }

    func test_ResourceLimitStatus_memoryExceeded() {
        let status: ResourceLimitStatus = .memoryExceeded(currentMB: 600, limitMB: 512)
        if case .memoryExceeded(let cur, let lim) = status {
            XCTAssertEqual(cur, 600)
            XCTAssertEqual(lim, 512)
        } else {
            XCTFail()
        }
    }

    func test_VSCodeExtensionManifest_creation() {
        let manifest = VSCodeExtensionManifest(
            extensionID: "test.extension",
            version: SemVer(1, 0, 0),
            enginesVSCode: "^1.85.0",
            activationEvents: ["onCommand:test.hello"],
            mainEntry: "extension.js",
            contributes: VSCodeContributes()
        )
        XCTAssertEqual(manifest.extensionID, "test.extension")
        XCTAssertEqual(manifest.enginesVSCode, "^1.85.0")
    }

    func test_JetBrainsPluginManifest_creation() {
        let manifest = JetBrainsPluginManifest(
            pluginID: "com.test.plugin",
            version: SemVer(1, 0, 0),
            sinceBuild: "241",
            mainJAR: "lib/test.jar"
        )
        XCTAssertEqual(manifest.pluginID, "com.test.plugin")
        XCTAssertEqual(manifest.sinceBuild, "241")
        XCTAssertNil(manifest.untilBuild)
    }

    func test_ArchitectureValidation_valid() {
        let val: ArchitectureValidation = .valid
        if case .valid = val {} else { XCTFail() }
    }

    func test_ArchitectureValidation_arm64Only() {
        let val: ArchitectureValidation = .arm64Only(module: "test")
        if case .arm64Only(let mod) = val {
            XCTAssertEqual(mod, "test")
        } else {
            XCTFail()
        }
    }

    func test_ProcessID_equality() {
        XCTAssertEqual(ProcessID(123), ProcessID(123))
        XCTAssertNotEqual(ProcessID(123), ProcessID(456))
    }

    func test_ProcessSignal_values() {
        let _: ProcessSignal = .terminate
        let _: ProcessSignal = .kill
        let _: ProcessSignal = .interrupt
    }

    func test_ExtensionHostError_values() {
        let err1: ExtensionHostError = .runtimeNotFound
        let err2: ExtensionHostError = .startupTimeout
        let err3: ExtensionHostError = .ipcChannelFailed
        let err4: ExtensionHostError = .resourceLimitExceeded
        XCTAssertNotEqual(err1, err2)
        XCTAssertNotEqual(err3, err4)
    }
}
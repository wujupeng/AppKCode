import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeExtensionHost

// MARK: - ExtensionEventBus Tests (TASK-017)

final class M810Phase3ExtensionEventBusTests: XCTestCase {

    func testTextChangeCreation() {
        let change = TextChange(rangeStartLine: 0, rangeStartCharacter: 0, rangeEndLine: 0, rangeEndCharacter: 5, text: "hello")
        XCTAssertEqual(change.text, "hello")
        XCTAssertEqual(change.rangeStartLine, 0)
    }

    func testDiagnosticItemCreation() {
        let item = DiagnosticItem(startLine: 0, startCharacter: 0, endLine: 0, endCharacter: 5, severity: 1, message: "Error", source: "test")
        XCTAssertEqual(item.message, "Error")
        XCTAssertEqual(item.severity, 1)
    }

    func testExtensionOutboundEventOnDidChangeTextDocument() {
        let extID = ExtensionID("test-ext")
        let event = ExtensionOutboundEvent.onDidChangeTextDocument(
            extensionID: extID,
            uri: "file:///test.swift",
            changes: []
        )
        if case .onDidChangeTextDocument(let ext, let uri, let changes) = event {
            XCTAssertEqual(ext, extID)
            XCTAssertEqual(uri, "file:///test.swift")
            XCTAssertEqual(changes.count, 0)
        } else {
            XCTFail("Wrong event type")
        }
    }

    func testExtensionOutboundEventOnDidSaveTextDocument() {
        let extID = ExtensionID("test-ext")
        let event = ExtensionOutboundEvent.onDidSaveTextDocument(extensionID: extID, uri: "file:///test.swift")
        if case .onDidSaveTextDocument(let ext, let uri) = event {
            XCTAssertEqual(ext, extID)
            XCTAssertEqual(uri, "file:///test.swift")
        } else {
            XCTFail("Wrong event type")
        }
    }

    func testExtensionOutboundEventDiagnostics() {
        let extID = ExtensionID("test-ext")
        let event = ExtensionOutboundEvent.diagnostics(
            extensionID: extID,
            uri: "file:///test.swift",
            diagnostics: []
        )
        if case .diagnostics(let ext, let uri, let diags) = event {
            XCTAssertEqual(ext, extID)
            XCTAssertEqual(uri, "file:///test.swift")
            XCTAssertEqual(diags.count, 0)
        } else {
            XCTFail("Wrong event type")
        }
    }

    func testExtensionInboundEventOnDidChangeConfiguration() {
        let event = ExtensionInboundEvent.onDidChangeConfiguration(key: "editor.fontSize", value: .int(14))
        if case .onDidChangeConfiguration(let key, let value) = event {
            XCTAssertEqual(key, "editor.fontSize")
            XCTAssertEqual(value, .int(14))
        } else {
            XCTFail("Wrong event type")
        }
    }

    func testExtensionInboundEventOnDidChangeWorkspaceFolders() {
        let event = ExtensionInboundEvent.onDidChangeWorkspaceFolders(added: ["/new"], removed: ["/old"])
        if case .onDidChangeWorkspaceFolders(let added, let removed) = event {
            XCTAssertEqual(added, ["/new"])
            XCTAssertEqual(removed, ["/old"])
        } else {
            XCTFail("Wrong event type")
        }
    }

    func testExtensionInboundEventOnDidOpenTextDocument() {
        let event = ExtensionInboundEvent.onDidOpenTextDocument(uri: "file:///test.swift", languageID: "swift")
        if case .onDidOpenTextDocument(let uri, let lang) = event {
            XCTAssertEqual(uri, "file:///test.swift")
            XCTAssertEqual(lang, "swift")
        } else {
            XCTFail("Wrong event type")
        }
    }

    func testExtensionInboundEventOnDidCloseTextDocument() {
        let event = ExtensionInboundEvent.onDidCloseTextDocument(uri: "file:///test.swift")
        if case .onDidCloseTextDocument(let uri) = event {
            XCTAssertEqual(uri, "file:///test.swift")
        } else {
            XCTFail("Wrong event type")
        }
    }

    func testBackpressureStrategyDropOldest() {
        let strategy = BackpressureStrategy.dropOldest
        XCTAssertEqual(strategy.rawValue, "dropOldest")
    }

    func testBackpressureStrategyCoalesce() {
        let strategy = BackpressureStrategy.coalesce
        XCTAssertEqual(strategy.rawValue, "coalesce")
    }

    func testBackpressureStrategySample() {
        let strategy = BackpressureStrategy.sample(rate: 0.5)
        XCTAssertEqual(strategy.rawValue, "sample")
    }

    func testEventBusCreation() {
        let bus = ExtensionEventBusImpl()
        XCTAssertNotNil(bus)
    }

    func testEventBusSetBackpressureStrategy() {
        let bus = ExtensionEventBusImpl()
        bus.setBackpressureStrategy(.dropOldest)
        bus.setBackpressureStrategy(.coalesce)
        bus.setBackpressureStrategy(.sample(rate: 0.5))
    }

    func testEventBusSubscribeExtensionEvents() {
        let bus = ExtensionEventBusImpl()
        let extID = ExtensionID("test-ext")
        let stream = bus.subscribeExtensionEvents(extensionID: extID)
        XCTAssertNotNil(stream)
    }

    func testEventBusSubscribeHostEvents() {
        let bus = ExtensionEventBusImpl()
        let extID = ExtensionID("test-ext")
        let stream = bus.subscribeHostEvents(extensionID: extID)
        XCTAssertNotNil(stream)
    }

    func testEventBusPublishOutboundOnDidSave() async throws {
        let bus = ExtensionEventBusImpl()
        let extID = ExtensionID("test-ext")
        let _ = bus.subscribeExtensionEvents(extensionID: extID)
        try await bus.publishOutbound(.onDidSaveTextDocument(extensionID: extID, uri: "file:///test.swift"))
        XCTAssertGreaterThan(bus.auditLogCount, 0)
    }

    func testEventBusPublishInbound() async throws {
        let bus = ExtensionEventBusImpl()
        let extID = ExtensionID("test-ext")
        let _ = bus.subscribeHostEvents(extensionID: extID)
        try await bus.publishInbound(.onDidChangeConfiguration(key: "test", value: .null))
        XCTAssertGreaterThan(bus.auditLogCount, 0)
    }
}

// MARK: - ExtensionHostSupervisor Tests (TASK-018)

final class M810Phase3ExtensionHostSupervisorTests: XCTestCase {

    func testSupervisorInitialValues() {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 3000, crashLimit: 3)
        XCTAssertEqual(supervisor.crashCount, 0)
        XCTAssertTrue(supervisor.isStable)
    }

    func testSupervisorCustomConfig() {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 5000, crashLimit: 5)
        XCTAssertEqual(supervisor.crashCount, 0)
        XCTAssertTrue(supervisor.isStable)
    }

    func testHostCrashEventCreation() {
        let event = HostCrashEvent(
            hostType: .vscodeExtensionHost,
            processID: ProcessID(12345),
            exitCode: -1,
            crashCount60s: 1
        )
        XCTAssertEqual(event.hostType, .vscodeExtensionHost)
        XCTAssertEqual(event.processID, ProcessID(12345))
        XCTAssertEqual(event.exitCode, -1)
        XCTAssertEqual(event.crashCount60s, 1)
    }

    func testHostRestartEventCreation() {
        let event = HostRestartEvent(
            hostType: .vscodeExtensionHost,
            newProcessID: ProcessID(67890),
            restartReason: .crash
        )
        XCTAssertEqual(event.hostType, .vscodeExtensionHost)
        XCTAssertEqual(event.newProcessID, ProcessID(67890))
        XCTAssertEqual(event.restartReason, .crash)
    }

    func testRestartReasonEnum() {
        XCTAssertEqual(RestartReason.crash.rawValue, "crash")
        XCTAssertEqual(RestartReason.resourceLimitExceeded.rawValue, "resourceLimitExceeded")
        XCTAssertEqual(RestartReason.manual.rawValue, "manual")
    }

    func testCrashEventsStream() {
        let supervisor = ExtensionHostSupervisorImpl()
        let stream = supervisor.crashEvents()
        XCTAssertNotNil(stream)
    }

    func testRestartEventsStream() {
        let supervisor = ExtensionHostSupervisorImpl()
        let stream = supervisor.restartEvents()
        XCTAssertNotNil(stream)
    }

    func testSupervisorAuditRecordCounts() {
        let supervisor = ExtensionHostSupervisorImpl()
        XCTAssertEqual(supervisor.crashAuditRecordCount, 0)
        XCTAssertEqual(supervisor.restartAuditRecordCount, 0)
    }
}

// MARK: - StreamingCapabilityResult Tests (TASK-019)

final class M810Phase3StreamingTypesTests: XCTestCase {

    func testStreamingCapabilityResultCreation() {
        let result = StreamingCapabilityResult(
            chunkIndex: 0,
            chunkData: .string("chunk1"),
            isFinal: false
        )
        XCTAssertEqual(result.chunkIndex, 0)
        XCTAssertEqual(result.chunkData, .string("chunk1"))
        XCTAssertFalse(result.isFinal)
        XCTAssertNil(result.error)
    }

    func testStreamingCapabilityResultFinal() {
        let result = StreamingCapabilityResult(
            chunkIndex: 5,
            chunkData: .string("last"),
            isFinal: true,
            totalChunks: 6
        )
        XCTAssertTrue(result.isFinal)
        XCTAssertEqual(result.totalChunks, 6)
    }

    func testStreamingCapabilityResultWithError() {
        let result = StreamingCapabilityResult(
            chunkIndex: 0,
            chunkData: .null,
            isFinal: true,
            error: StreamingError(code: -1, message: "Host crashed", recoverable: true)
        )
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.recoverable == true)
    }

    func testStreamingErrorCreation() {
        let error = StreamingError(code: -32603, message: "Internal error", recoverable: false)
        XCTAssertEqual(error.code, -32603)
        XCTAssertEqual(error.message, "Internal error")
        XCTAssertFalse(error.recoverable)
    }
}

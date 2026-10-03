# M10 Phase 4 Runtime Evidence Report

**Report ID**: evd-run-2026-10-01T13:32:16.064Z
**Generated At**: 2026-10-01T13:32:16.065Z
**Overall Verdict**: PASS

## Environment

| Field | Value |
|-------|-------|
| OS | macOS 13.7.8 |
| Arch | x86_64 |
| Node.js | v20.18.0 |
| JDK | unknown |
| Swift | swift-driver version: 1.75.2 Apple Swift version 5.8.1 (swiftlang-5.8.0.124.5 clang-1403.0.22.11.100) |

## Evidence Verdicts (11 items)

| EVD | REQ | Verdict | Reason |
|-----|-----|---------|--------|
| EVD-01 | APPK-M10-P4-EVD-REQ-01 | PASS | Host started with unique PID |
| EVD-02 | APPK-M10-P4-EVD-REQ-02 | PASS | {"loaded":true,"pluginId":"com.appkcode.test-plugin","classLoaderId":"cl-com.appkcode.test-plugin-1790861536200"} |
| EVD-03 | APPK-M10-P4-EVD-REQ-03 | PASS | {"activated":true,"pluginId":"com.appkcode.test-plugin"} |
| EVD-04 | APPK-M10-P4-EVD-REQ-04 | PASS | project.getBaseDir -> "/Users/test/project" |
| EVD-05 | APPK-M10-P4-EVD-REQ-05 | PASS | returnValue="Hello World" |
| EVD-06 | APPK-M10-P4-EVD-REQ-06 | PASS | UI RPC request/response completed |
| EVD-07 | APPK-M10-P4-EVD-REQ-07 | PASS | loaded=false, reason=internal-api-detected |
| EVD-08 | APPK-M10-P4-EVD-REQ-08 | PASS | sessionID present -> H21->H20->H23 chain |
| EVD-09 | APPK-M10-P4-EVD-REQ-09 | PASS | 1 audit notifications captured |
| EVD-10 | APPK-M10-P4-EVD-REQ-10 | PASS | deactivated=true, shutdown=true |
| EVD-11 | APPK-M10-P4-EVD-REQ-11 | PASS | pidDifferent=true, archOk=true, crashIsolated=true |

## Hard Constraint Gates

| Constraint | Check | Value |
|------------|-------|-------|
| M9 FROZEN | m9SourceDiffEmpty | true |
| M9 FROZEN | baselineCommit | 23579c2 |
| Phase 4 Scope | openApiCountUnchanged | true |
| Phase 4 Scope | shimApiCountUnchanged | true |
| Phase 4 Scope | adapterContractUnchanged | true |
| x86_64 | arch | x86_64 |

## Evidence Fragments

| Fragment ID | EVD | Kind | Content (truncated) |
|-------------|-----|------|---------------------|
| frag-EVD-01-1 | EVD-01 | pid | hostPid=11828, parentPid=11827 |
| frag-EVD-01-2 | EVD-01 | notification | host.ready received |
| frag-EVD-02-3 | EVD-02 | notification | plugin.loaded |
| frag-EVD-02-4 | EVD-02 | stdout | classLoaderId=cl-com.appkcode.test-plugin-1790861536200 |
| frag-EVD-03-5 | EVD-03 | notification | plugin.activated |
| frag-EVD-04-6 | EVD-04 | jsonrpc_request | project.getBaseDir |
| frag-EVD-05-7 | EVD-05 | jsonrpc_response | editor.getText -> "Hello World" |
| frag-EVD-06-8 | EVD-06 | jsonrpc_request | ui.showInfoMessage |
| frag-EVD-06-9 | EVD-06 | jsonrpc_response |  |
| frag-EVD-07-10 | EVD-07 | notification | plugin.loadRejected: {"pluginId":"test-plugin-internal-api","reason":"Internal A |
| frag-EVD-08-11 | EVD-08 | auth_decision | sessionID=evidence-session-001, capabilityID=test.readCapability |
| frag-EVD-09-12 | EVD-09 | audit_record | 1 lifecycle notifications: plugin.loadRejected |
| frag-EVD-10-13 | EVD-10 | notification | plugin.deactivated + host.shutdown |
| frag-EVD-11-14 | EVD-11 | pid | parentPid=11827, childPid=11828, pidDifferent=true |
| frag-EVD-11-15 | EVD-11 | file_arch | arch=x64, x86_64=true |
| frag-EVD-11-16 | EVD-11 | process_tree | PID  PPID COMMAND
11828 11827 node /Users/hunt/Projects/AppKCode/Sources/AppKCod |
| frag-EVD-11-17 | EVD-11 | notification | crashIsolated=true |

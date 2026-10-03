# M10 Phase 6 TASK-035 Gate Evidence

## Task: APPK-M10-TASK-035 — 全链路集成测试（H19）

**Status**: 🟢 PASS / CLOSED  
**Date**: 2026-10-03  
**Commit**: pending  

---

## 验收标准

> Extension 加载经完整 H19 链路；每步可审计查询；不存在直通路径

---

## 子任务完成情况

### TASK-035.1: H19 Full Chain (REQ-050) — 10 tests
- ✅ `testH19_manifestParsingProducesValidManifest` — Manifest 解析产生有效 manifest
- ✅ `testH19_contractQueryFindsRegisteredContract` — Contract 查询找到已注册 contract (H21)
- ✅ `testH19_versionNegotiationSucceedsForCompatibleExtension` — 版本协商成功 (H24)
- ✅ `testH19_hostStartupCreatesRunningProcess` — Host 启动创建运行进程
- ✅ `testH19_activateExtensionProducesInstanceID` — activateExtension 产生实例 ID
- ✅ `testH19_apiCallGoesThroughContract` — API 调用经 Contract 强制 (H21)
- ✅ `testH19_apiCallGoesThroughAuthorization` — API 调用经 Authorization (H20)
- ✅ `testH19_auditRecordedForEachLifecycleStep` — 每个生命周期步骤记录审计 (H23)
- ✅ `testH19_fullChainEachStepAuditable` — 全链路每步可审计查询
- ✅ `testH19_noDirectPathFromExtensionToExecution` — 高危操作无直通路径，需审批 (H20)

### TASK-035.2: H19 禁止直通 (source scan) — 5 tests
- ✅ `testH19_noDirectProcessInSharedCompatibility` — Shared/Compatibility 无 `Process()` 直接调用
- ✅ `testH19_noDirectProcessInDomainCompatibility` — Domain/Compatibility 无 `Process()` 直接调用
- ✅ `testH19_noDirectProcessInApplicationCompatibility` — Application/Compatibility 无 `Process()` 直接调用
- ✅ `testH19_noDirectFileManagerInCompatibilityLayer` — Compatibility 层无 `FileManager.default` 直接调用
- ✅ `testH19_noDirectGitInCompatibilityLayer` — Compatibility 层无 `"git ` 直接调用

### TASK-035.3: H19-H24 不可 bypass (source scan) — 3 tests
- ✅ `testH19_noBypassKeywordInM10Files` — M10 文件不含 bypass/autoApprove/skipAuth/skipApproval/directExecute/noAudit/directInternal/grantAll
- ✅ `testH19_noAutoApproveInM10Files` — M10 文件不含 `autoApprove`
- ✅ `testH19_noSkipAuthInM10Files` — M10 文件不含 `skipAuth`/`skipApproval`

### TASK-035.4: H22 IPC Isolation (REQ-036) — 5 tests
- ✅ `testH22_ipcMessageIsJSONSerializable` — IPCMessage JSON 编解码
- ✅ `testH22_ipcResponseIsJSONSerializable` — IPCResponse JSON 编解码
- ✅ `testH22_ipcErrorIsJSONSerializable` — IPCError JSON 编解码
- ✅ `testH22_ipcMessagePayloadIsAnyCodableValue` — 所有 AnyCodableValue 类型 JSON 可序列化
- ✅ `testH22_noInternalSwiftObjectReferencesInIPC` — IPC 类型全部 Codable，无内部 Swift 对象引用

### TASK-035.5: Streaming Full Chain (REQ-041) — 7 tests
- ✅ `testStreaming_contractEnforcedBeforeStreaming` — 未注册 capability 抛异常 (H21)
- ✅ `testStreaming_authorizationEnforcedBeforeStreaming` — 高危无审批产生错误流 (H20)
- ✅ `testStreaming_auditRecordedForDeniedStream` — 拒绝流记录审计 (H23)
- ✅ `testStreaming_auditRecordedForApprovalRequired` — 需审批流记录审计 (H23)
- ✅ `testStreaming_auditRecordedForAllowedStream` — 允许流记录审计 (H23)
- ✅ `testStreaming_deniedProducesErrorStream` — 拒绝流产生错误并终止
- ✅ `testStreaming_noBypassApproval` — 高危流无审批不可绕过 (H20, REQ-041)

---

## 测试结果

| 指标 | 值 |
|------|-----|
| TASK-035 测试数 | **30** |
| TASK-035 PASS | **30** |
| TASK-035 FAIL | **0** |
| 全量测试 | **1018/1018 PASS** |
| 全量 FAIL | **0** |
| 构建结果 | **Build complete!** |
| Arch Check | **x86_64 PASSED** |

---

## M9 FROZEN 验证

```
git diff --name-only 23579c2 -- Sources/ | while read f; do
  if git cat-file -e 23579c2:$f 2>/dev/null; then echo "M9_MODIFIED: $f"; fi
done
```

**结果**: 空（无 M9 源文件被修改）✅

---

## H19 全链路验证

| 链路步骤 | 验证测试 | 状态 |
|----------|----------|------|
| Manifest 解析 | testH19_manifestParsingProducesValidManifest | ✅ |
| Contract 查询 (H21) | testH19_contractQueryFindsRegisteredContract | ✅ |
| 版本协商 (H24) | testH19_versionNegotiationSucceedsForCompatibleExtension | ✅ |
| Host 启动 | testH19_hostStartupCreatesRunningProcess | ✅ |
| activate | testH19_activateExtensionProducesInstanceID | ✅ |
| API 调用 (H21) | testH19_apiCallGoesThroughContract | ✅ |
| Authorization (H20) | testH19_apiCallGoesThroughAuthorization | ✅ |
| Audit (H23) | testH19_auditRecordedForEachLifecycleStep | ✅ |
| 全链路可审计 | testH19_fullChainEachStepAuditable | ✅ |
| 无直通路径 | testH19_noDirectPathFromExtensionToExecution | ✅ |

---

## H19 禁止直通验证 (source scan)

| 扫描范围 | 禁止模式 | 状态 |
|----------|----------|------|
| Shared/Compatibility | `Process()` | ✅ 无违规 |
| Domain/Compatibility | `Process()` | ✅ 无违规 |
| Application/Compatibility | `Process()` | ✅ 无违规 |
| Shared+Domain/Compatibility | `FileManager.default` | ✅ 无违规 |
| All Compatibility | `"git ` | ✅ 无违规 |

**架构边界说明**: ExtensionHost/Compatibility 层允许使用 `Process()`（进程管理是 enforcement layer 的职责），Compatibility adapter 层（Shared/Domain/Application）不允许直接使用。

---

## H19-H24 不可 bypass 验证

| 关键字 | 状态 |
|--------|------|
| bypass | ✅ 不存在 |
| autoApprove | ✅ 不存在 |
| skipAuth | ✅ 不存在 |
| skipApproval | ✅ 不存在 |
| directExecute | ✅ 不存在 |
| noAudit | ✅ 不存在 |
| directInternal | ✅ 不存在 |
| grantAll | ✅ 不存在 |

---

## H22 IPC 隔离验证

| 类型 | Codable | JSON 可序列化 | 无 Swift 对象引用 |
|------|---------|--------------|------------------|
| IPCMessage | ✅ | ✅ | ✅ |
| IPCResponse | ✅ | ✅ | ✅ |
| IPCError | ✅ | ✅ | ✅ |
| FileTransferRef | ✅ | ✅ | ✅ |
| AnyCodableValue (所有 case) | ✅ | ✅ | ✅ |

---

## 流式操作全链路验证 (REQ-041)

| 验证点 | 测试 | 状态 |
|--------|------|------|
| Contract 强制 | testStreaming_contractEnforcedBeforeStreaming | ✅ |
| Authorization 强制 | testStreaming_authorizationEnforcedBeforeStreaming | ✅ |
| Denied 审计 | testStreaming_auditRecordedForDeniedStream | ✅ |
| Approval 审计 | testStreaming_auditRecordedForApprovalRequired | ✅ |
| Allowed 审计 | testStreaming_auditRecordedForAllowedStream | ✅ |
| 错误流终止 | testStreaming_deniedProducesErrorStream | ✅ |
| 不可绕过审批 | testStreaming_noBypassApproval | ✅ |

---

## PM 重点要求回应

> H19 ≠ 单个模块测试简单拼接。要证明的是真实调用链保持边界。

**回应**:
1. **全链路连接**: `testH19_fullChainEachStepAuditable` 验证 9 步链路（manifest → contract → version → host → activate → api → auth → execute → audit）每步产生审计记录
2. **边界保持**: `testH19_noDirectPathFromExtensionToExecution` 证明高危操作必须经 `requiresUserApproval`，无直通路径
3. **源码扫描**: 5 个 source scan 测试证明 Compatibility adapter 层不直接调用 `Process()`/`FileManager.default`/`git`
4. **不可 bypass**: 3 个 source scan 测试证明 M10 源码不含 bypass/autoApprove/skipAuth 等关键字
5. **IPC 隔离**: 5 个测试证明 IPC 消息全部 JSON 可序列化，无内部 Swift 对象引用
6. **流式全链路**: 7 个测试证明流式操作每块经 Contract + Auth + Audit，不绕过审批

---

## 交付清单

- `Tests/AppKCodeIntegrationTests/M10FullChainIntegrationTests.swift`（30 tests）
  - Mock: FullChainPermissionService / FullChainVersionNegotiation / MockIPCChannel
  - 035.1: H19 Full Chain (10 tests)
  - 035.2: H19 禁止直通 source scan (5 tests)
  - 035.3: H19-H24 不可 bypass source scan (3 tests)
  - 035.4: H22 IPC Isolation (5 tests)
  - 035.5: Streaming Full Chain (7 tests)

---

## 结论

TASK-035 **PASS / CLOSED**。H19 全链路集成测试已通过验收。等待 PM 授权下一个 Task。
# APPK-M11 — G-AI / CodeArts Agent Integration Layer 编码任务规划

> **文档编号**: APPK-M11-TASKS-001
> **版本**: v1.0
> **状态**: Task Plan（待 PM Gate Review 授权）
> **对应需求**: APPK-SPEC-001 v0.1 §5.3 (AI Agent) / §5.6 (MCP) / §5.7 (Skills/Rules) / §5.14 (G-AI Bridge)
> **对应 Scope Review**: APPK-M11-SCOPE-001 `m11_scope_review.md`
> **对应设计**: APPK-M11-DESIGN-001 `m11_design.md`
> **里程碑**: M11 — G-AI / CodeArts Agent Integration
> **前置基线**: M10 FROZEN commit `81bb91f`（1103/1103 tests PASS），M9 FROZEN `23579c2`（625/625 tests）
> **构建环境**: macOS 13.0, Swift 5.8, x86_64-apple-macos13.0
> **日期**: 2026-10-04
> **文档性质**: 编码任务规划（非编码任务本身，不产生 Swift 代码，不修改 M0-M10 任何源文件或测试文件）

---

## 0. 文档目的与范围

本文档是 M11 里程碑的**编码任务规划文档**，基于 `m11_scope_review.md`（P0 Scope Review）和 `m11_design.md`（技术设计），将"HOW"（技术设计）转化为可执行、可验收的编码任务清单（"DO"）。

**本文档产出**：仅 `m11_tasks.md` 一份文档，包含：
1. 任务编号规范
2. Phase 间依赖关系
3. P1-P8 每个 Phase 的主任务与子任务
4. 每个 Task 的输入/输出/依赖/验收标准/涉及文件/复用既有能力/硬约束映射
5. Exit Gate 定义
6. 硬约束映射矩阵
7. M10 Frozen Baseline 保护规则
8. x86_64 约束
9. 明确禁止事项

**本文档不**：
- ❌ 不修改 M0-M10 任何源文件或测试文件
- ❌ 不创建任何 Swift 代码（仅规划任务）
- ❌ 不修改 M10 FROZEN 基线（commit `81bb91f`）
- ❌ 不修改 M9 FROZEN 基线（commit `23579c2`）
- ❌ 不 reset / amend 已有 Frozen Commit
- ❌ 不自动授权任何 Phase 的执行（每 Phase 需 PM Gate Review 授权）

---

## 1. 任务编号规范

### 1.1 编号格式

| 类型 | 格式 | 示例 |
|------|------|------|
| 主任务 | `M11-P{Phase}-TASK-{XXX}` | `M11-P1-TASK-001` |
| 子任务 | `M11-P{Phase}-TASK-{XXX}.{Y}` | `M11-P1-TASK-001.1` |

- **Phase**：1-8（P0 已完成，不含在此）
- **XXX**：001 起始，三位数，Phase 内连续编号
- **Y**：1 起始，一位数，主任务内连续编号

### 1.2 任务状态

| 状态 | 含义 |
|------|------|
| `PLANNED` | 已规划，待 PM 授权 |
| `AUTHORIZED` | PM 已授权，可执行 |
| `IN_PROGRESS` | 执行中 |
| `DONE` | 已完成，Exit Gate PASS |
| `BLOCKED` | 阻塞，需 PM 裁定 |
| `REJECTED` | PM 拒绝授权 |

---

## 2. Phase 间依赖关系

### 2.1 依赖关系图

```
M11-P0 (Scope Review) ✅ 已完成
    │
    ▼
M11-P1 (G-AI Provider / API Contract)
    │
    ▼
M11-P2 (Agent Context Bridge)
    │
    ▼
M11-P3 (Agent ↔ MCP / Skills / Rules)
    │
    ▼
M11-P4 (AI Capability Authorization)
    │
    ▼
M11-P5 (AI Tool Execution + Audit)
    │
    ▼
M11-P6 (CodeArts Agent Integration)
    │
    ▼
M11-P7 (End-to-End Agent Runtime)
    │
    ▼
M11-P8 (Final Integration / Regression / Exit)
```

### 2.2 依赖关系矩阵

| Phase | 前置 Phase | 产出依赖 | 硬约束覆盖 |
|-------|-----------|---------|-----------|
| P1 | P0 | `GAIRuntimeBridge` 协议 | H3/H9/H11/H28-1 |
| P2 | P1 | `AgentContextBridge` 协议 | H10/H22/H28 |
| P3 | P2 | `AIToolInvocationBridge` 协议 | H15/H16/H17/H28-2/H28-7/H28-8/H28-9 |
| P4 | P3 | `AICapabilityAuthorizationBridge` 协议 | H2/H12/H20/H21/H28-3/H28-4/H28-5 |
| P5 | P4 | `AIAuditBridge` 协议 + `AuditTarget` 扩展 | H14/H18/H23/H28-6/H28-10 |
| P6 | P5 | `CodeArtsAgentOrchestrator` | H19-H28 |
| P7 | P6 | `GAIIntegrationOrchestrator` + 端到端测试 | H1-H28 |
| P8 | P7 | `m11_exit_report.md` | H1-H28 |

### 2.3 跨 Phase 引用说明

- P1 实现 `GAIRuntimeBridgeImpl` 时引用 P5 `AIAuditBridge`（审计）。由于 P5 在 P1 之后，P1 阶段先定义 `AIAuditBridge` protocol 占位（仅 protocol，不实现），P5 阶段补充实现。**或者**：调整实现顺序，P1 的 `GAIRuntimeBridgeImpl` 在 P5 完成后补充审计调用（P1 先完成协议定义 + 基本流程，审计接入在 P5 后回填）。本任务规划采用**协议前置定义**策略：P1 阶段定义 `AIAuditBridge` protocol（仅签名），P5 阶段实现 `AIAuditBridgeImpl`。
- P3 实现 `AIToolInvocationBridgeImpl` 时引用 P4 `AICapabilityAuthorizationBridge`（授权）。同理，P3 阶段定义 `AICapabilityAuthorizationBridge` protocol（仅签名），P4 阶段实现。

---

## 3. M11-P1: G-AI Provider / API Contract

**Phase 目标**：定义 G-AI Runtime 流程驱动接口（`GAIRuntimeBridge` 协议），将 SPEC→DESIGN→TASK→IMPLEMENTATION→TEST→EVIDENCE→REVIEW→GATE 状态机桥接到 M7 `AgentRuntimeOrchestrator`。

**Phase 前置**：P0 Scope Review 完成 + PM 授权 P1

**Phase 硬约束**：H3 / H9 / H11 / H28-1

**Phase 不修改**：M6 / M7 任何源文件

### M11-P1-TASK-001: 定义 G-AI 流程驱动值类型与枚举

**任务描述**：在 Domain 层定义 G-AI 流程驱动的值类型与枚举，均需 `Sendable + Codable + Equatable`。

**输入**：`m11_design.md` §2.2.2.1 接口签名

**输出**：G-AI 流程类型定义文件

**依赖**：无（Phase 起始任务）

**验收标准**：
- 所有类型均为 `Sendable + Codable + Equatable`
- `GAIWorkflowPhase` 含 8 个 case（spec/design/task/implementation/test/evidence/review/gate）
- `GAIWorkflowStatus` 含 6 个 case（pending/inProgress/awaitingApproval/completed/rejected/cancelled）
- `GAIWorkflowTask` 含 `maxSteps: Int` 字段（防止无限循环）
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeDomain/GAIBridge/GAIWorkflowTypes.swift` — `GAIWorkflowTask` / `GAIWorkflowState` / `GAIWorkflowEvidence` struct + `GAIWorkflowTaskID` + `GAIWorkflowPhase` / `GAIWorkflowStatus` enum

**复用既有能力**：M6 `ChatInferenceRequest`（类型风格参考，不修改）

**硬约束映射**：H28（类型定义为 H28 桥接基础）

#### M11-P1-TASK-001.1: 定义 GAIWorkflowPhase / GAIWorkflowStatus 枚举
- [ ] 在 `Sources/AppKCodeDomain/GAIBridge/GAIWorkflowTypes.swift` 中定义 `GAIWorkflowPhase` enum（8 个 case: spec/design/task/implementation/test/evidence/review/gate），`String, Sendable, Codable, Equatable`
- [ ] 定义 `GAIWorkflowStatus` enum（6 个 case: pending/inProgress/awaitingApproval/completed/rejected/cancelled），`String, Sendable, Codable, Equatable`

#### M11-P1-TASK-001.2: 定义 GAIWorkflowTask / GAIWorkflowState / GAIWorkflowEvidence 值类型
- [ ] 定义 `GAIWorkflowTaskID`（UUID 包装类型，`Sendable + Codable + Equatable + Hashable`）
- [ ] 定义 `GAIWorkflowTask` struct（id / phase / userRequest / contextRequest / maxSteps），`Sendable + Codable + Equatable`
- [ ] 定义 `GAIWorkflowEvidence` struct（phase / evidenceType / payload / timestamp），`Sendable + Codable + Equatable`
- [ ] 定义 `GAIWorkflowState` struct（taskID / currentPhase / status / evidenceChain / gateResult），`Sendable + Codable + Equatable`
- [ ] 定义 `GateResult` struct（verdict: PASS/FAIL / summary / timestamp），`Sendable + Codable + Equatable`（如不存在）

#### M11-P1-TASK-001.3: 验证类型构建通过
- [ ] `swift build` → 0 errors
- [ ] 验证所有类型 `Sendable + Codable + Equatable` 编译通过

---

### M11-P1-TASK-002: 定义 GAIRuntimeBridge 协议

**任务描述**：在 Domain 层定义 `GAIRuntimeBridge` protocol，作为 G-AI Runtime 流程驱动的唯一桥接入口。

**输入**：`m11_design.md` §2.2.2.1 接口签名 + TASK-001 类型定义

**输出**：`GAIRuntimeBridge` protocol 定义文件

**依赖**：M11-P1-TASK-001

**验收标准**：
- `GAIRuntimeBridge` protocol 为 `Sendable`
- 含 4 个方法：`submitTask` / `advance` / `currentState` / `cancel`
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeDomain/GAIBridge/GAIRuntimeBridge.swift` — `GAIRuntimeBridge` protocol

**复用既有能力**：M7 `AgentSessionID`（引用，不修改）

**硬约束映射**：H28（协议为 H28 桥接入口）

#### M11-P1-TASK-002.1: 定义 GAIRuntimeBridge protocol
- [ ] 在 `Sources/AppKCodeDomain/GAIBridge/GAIRuntimeBridge.swift` 中定义 `GAIRuntimeBridge: Sendable` protocol
- [ ] 定义 `submitTask(_ task: GAIWorkflowTask) async throws -> GAIWorkflowState`
- [ ] 定义 `advance(phase: GAIWorkflowPhase, session: AgentSessionID) async throws -> GAIWorkflowState`
- [ ] 定义 `currentState(session: AgentSessionID) async throws -> GAIWorkflowState`
- [ ] 定义 `cancel(session: AgentSessionID) async throws`

#### M11-P1-TASK-002.2: 定义 GAIError 错误类型
- [ ] 定义 `GAIError` enum（`unknownPhase` / `maxStepsExceeded` / `authorizationDenied` / `sessionNotFound` / `alreadyCompleted`），`Error + Sendable + Equatable`
- [ ] 异常映射：`GAIError.unknownPhase` → `M11-P1-001`，`maxStepsExceeded` → `M11-P1-002`，`authorizationDenied` → `M11-P1-003`

#### M11-P1-TASK-002.3: 前置定义 AIAuditBridge protocol（仅签名，P5 实现）
- [ ] 在 `Sources/AppKCodeDomain/GAIBridge/AIAuditBridge.swift` 中前置定义 `AIAuditBridge: Sendable` protocol（仅 `record` 方法签名）
- [ ] 前置定义 `AIAuditEvent` / `AIAuditEventKind` / `AuditTarget` 扩展占位（P5 阶段补充实现）
- [ ] 注释标注：`// M11-P5 将补充 AIAuditBridgeImpl 实现`

---

### M11-P1-TASK-003: 实现 GAIRuntimeBridgeImpl

**任务描述**：在 Application 层实现 `GAIRuntimeBridgeImpl`，通过依赖注入复用 M6 `ModelProviderRegistry` + M7 `AgentRuntimeOrchestrator`，将 G-AI 流程任务桥接到既有 Agent Runtime。

**输入**：TASK-002 协议定义 + M6 `ModelProviderRegistry` / `AIBoundaryValidator` + M7 `AgentRuntimeOrchestrator`

**输出**：`GAIRuntimeBridgeImpl` 实现文件

**依赖**：M11-P1-TASK-002

**验收标准**：
- `GAIRuntimeBridgeImpl` 为 `final class + @unchecked Sendable`
- 通过依赖注入接收 M6 / M7 组件（不修改既有实现）
- `submitTask` 将 `GAIWorkflowTask` 转换为 M7 `AgentRequest`，调用 `AgentRuntimeOrchestrator.runRequest`
- 推理请求经 M6 `ModelProviderRegistry.resolve` + `AIBoundaryValidator.validate`（H9，H28-1）
- `maxSteps` 限制生效（超过抛出 `GAIError.maxStepsExceeded`）
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeApplication/GAIBridge/GAIRuntimeBridgeImpl.swift` — `GAIRuntimeBridgeImpl` 实现

**复用既有能力**：
- M6 `ModelProviderRegistry.resolve`（H9，不修改）
- M6 `AIBoundaryValidator.validate`（H9，H28-1，不修改）
- M7 `AgentRuntimeOrchestrator.runRequest`（H12/H14，不修改）

**硬约束映射**：H3 / H9 / H11 / H28-1

#### M11-P1-TASK-003.1: 实现 GAIRuntimeBridgeImpl 依赖注入
- [ ] 定义 `GAIRuntimeBridgeImpl` final class，`@unchecked Sendable`
- [ ] `init(modelProviderRegistry: ModelProviderRegistry, aiBoundaryValidator: AIBoundaryValidator, orchestrator: AgentRuntimeOrchestrator, auditBridge: AIAuditBridge?)`（auditBridge 可选，P5 后注入）
- [ ] 内部维护 `[AgentSessionID: GAIWorkflowState]` 会话状态（线程安全，`actor` 或锁保护）

#### M11-P1-TASK-003.2: 实现 submitTask
- [ ] 校验 `task.maxSteps > 0`（防止无限循环）
- [ ] 经 `aiBoundaryValidator.validate(capability)` 校验 AI 边界（H9，H28-1）
- [ ] 经 `modelProviderRegistry.resolve(provider)` 解析 Provider（H3/H11）
- [ ] 将 `GAIWorkflowTask` 转换为 M7 `AgentRequest`
- [ ] 调用 `orchestrator.runRequest`（不修改 Orchestrator）
- [ ] 初始化 `GAIWorkflowState`（status: .pending）
- [ ] 如 `auditBridge` 非空，记录 `gaiWorkflowPhaseStarted` 审计事件

#### M11-P1-TASK-003.3: 实现 advance（状态机推进）
- [ ] 校验 `phase` 合法（否则抛 `GAIError.unknownPhase`）
- [ ] 校验当前状态允许推进（如已 completed/rejected/cancelled 则拒绝）
- [ ] 校验步数未超 `maxSteps`（否则抛 `GAIError.maxStepsExceeded`）
- [ ] 高危阶段（implementation）经 M7 `AuthorizationGate`（H12，H28-3）— 由 Orchestrator 内部保障
- [ ] 推进 `GAIWorkflowState.currentPhase` + 追加 `evidenceChain`
- [ ] 如 `auditBridge` 非空，记录 `gaiWorkflowPhaseCompleted` 审计事件

#### M11-P1-TASK-003.4: 实现 currentState / cancel
- [ ] `currentState(session)` 返回当前 `GAIWorkflowState`
- [ ] `cancel(session)` 设置 status 为 `.cancelled`，调用 M7 会话取消（如 Orchestrator 支持）

#### M11-P1-TASK-003.5: 验证实现构建通过
- [ ] `swift build` → 0 errors
- [ ] 验证不修改 M6 / M7 任何源文件（`git diff` 校验）

---

### M11-P1-TASK-004: P1 单元测试与状态机测试

**任务描述**：为 P1 的协议与实现编写单元测试，覆盖状态机转换、maxSteps 限制、H28-1 验收。

**输入**：TASK-003 实现

**输出**：P1 测试文件

**依赖**：M11-P1-TASK-003

**验收标准**：
- 所有新增测试 PASS
- M0-M10 既有 1103 tests 全部 PASS（回归）
- H28-1 验收测试 PASS

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/GAIRuntimeBridgeTests.swift`
- `Tests/AppKCodeApplicationTests/GAIBridge/GAIWorkflowStateMachineTests.swift`

**复用既有能力**：M6 / M7 既有测试风格（参考，不修改）

**硬约束映射**：H28-1

#### M11-P1-TASK-004.1: GAIRuntimeBridge 协议测试
- [ ] 测试 `submitTask` 返回 `GAIWorkflowState`（status: .pending）
- [ ] 测试 `currentState` 返回正确状态
- [ ] 测试 `cancel` 设置 status 为 .cancelled

#### M11-P1-TASK-004.2: GAIWorkflowStateMachine 状态转换测试
- [ ] 测试 spec → design → task → implementation → test → evidence → review → gate 合法转换
- [ ] 测试非法 phase 抛 `GAIError.unknownPhase`
- [ ] 测试已 completed/rejected/cancelled 状态拒绝推进
- [ ] 测试 `maxSteps` 超限抛 `GAIError.maxStepsExceeded`

#### M11-P1-TASK-004.3: H28-1 验收测试
- [ ] `testH28_1_gaiInferenceViaModelProviderAndAIBoundaryValidator`：断言 G-AI 推理请求经 M6 `ModelProviderRegistry.resolve` + `AIBoundaryValidator.validate`
- [ ] 断言不绕过 `AIBoundaryValidator`（H9）

#### M11-P1-TASK-004.4: 运行测试并验证回归
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1 新增 tests PASS
- [ ] `arch-check.sh` → x86_64

---

### M11-P1-TASK-005: P1 Exit Gate 验证

**任务描述**：执行 P1 Exit Gate 全部验收检查，确认 P1 完成。

**输入**：TASK-001 ~ TASK-004 全部完成

**输出**：P1 Exit Gate 通过证据

**依赖**：M11-P1-TASK-004

**验收标准**（Exit Gate）：
- [ ] `swift build` → 0 errors
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1 新增 tests PASS
- [ ] `arch-check.sh` → x86_64（H1）
- [ ] M10 commit `81bb91f` 源文件 0 modified（`git diff 81bb91f -- Sources/` 校验，仅 M11 新增文件）
- [ ] M9 commit `23579c2` 源文件 0 modified
- [ ] H3 / H9 / H11 / H28-1 验收 PASS
- [ ] 不引入禁止项（无 AI → Shell 直接执行、无第二套审计系统等）
- [ ] PM Gate Review 通过，授权 P2

**涉及文件**：无新增（验证任务）

**硬约束映射**：H1 / H3 / H9 / H11 / H28-1

---

## 4. M11-P2: Agent Context Bridge

**Phase 目标**：定义 G-AI / CodeArts Agent 请求上下文的 Bridge 接口，经 M6 `ContextAggregator`（H10）聚合上下文，CodeArts Agent 经 M9 `PublicProtocolSurface`（H22）注入。

**Phase 前置**：P1 Exit Gate PASS + PM 授权 P2

**Phase 硬约束**：H10 / H22 / H28

**Phase 不修改**：M6 / M9 任何源文件

### M11-P2-TASK-001: 定义 AgentContextBridge 协议与值类型

**任务描述**：在 Domain 层定义 `AgentContextBridge` protocol 及相关值类型。

**输入**：`m11_design.md` §2.2.2.2 接口签名

**输出**：`AgentContextBridge` 协议定义文件

**依赖**：M11-P1-TASK-005（P1 Exit Gate PASS）

**验收标准**：
- `AgentContextBridge` protocol 为 `Sendable`
- `AgentContextRequest` / `AgentContextSource` 为 `Sendable + Codable + Equatable`
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeDomain/GAIBridge/AgentContextBridge.swift` — `AgentContextBridge` protocol + `AgentContextRequest` / `AgentContextSource`

**复用既有能力**：M6 `ContextBudget` / `ContextItem`（引用，不修改）

**硬约束映射**：H10 / H22

#### M11-P2-TASK-001.1: 定义 AgentContextSource 枚举
- [ ] 定义 `AgentContextSource` enum（3 个 case: gaiRuntime / codeArtsAgent / appkcodeAgent），`String, Sendable, Codable, Equatable`

#### M11-P2-TASK-001.2: 定义 AgentContextRequest 值类型
- [ ] 定义 `AgentContextRequest` struct（source / projectRoot / budget），`Sendable + Codable + Equatable`
- [ ] `budget` 引用 M6 `ContextBudget`（不修改）

#### M11-P2-TASK-001.3: 定义 AgentContextBridge protocol
- [ ] 定义 `AgentContextBridge: Sendable` protocol
- [ ] 定义 `gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem]`
- [ ] 异常映射：`ContextError.budgetExceeded` → `M11-P2-001`，`ContextError.surfaceViolation` → `M11-P2-002`（H22 违反）

---

### M11-P2-TASK-002: 实现 AgentContextBridgeImpl（G-AI 路径）

**任务描述**：在 Application 层实现 G-AI 路径的上下文桥接，经 M6 `ContextAggregator.gather`（H10）聚合上下文。

**输入**：TASK-001 协议 + M6 `ContextAggregator`

**输出**：`AgentContextBridgeImpl` 实现文件

**依赖**：M11-P2-TASK-001

**验收标准**：
- 经 M6 `ContextAggregator.gather`（H10，不修改）
- 返回 `[ContextItem]` 含 `source` 标注（H10）
- `ContextBudget` 截断生效
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeApplication/GAIBridge/AgentContextBridgeImpl.swift` — `AgentContextBridgeImpl` 实现

**复用既有能力**：M6 `ContextAggregator.gather` + 8 个 `ContextProvider`（H10，不修改）

**硬约束映射**：H10

#### M11-P2-TASK-002.1: 实现 AgentContextBridgeImpl 依赖注入
- [ ] 定义 `AgentContextBridgeImpl` final class，`@unchecked Sendable`
- [ ] `init(contextAggregator: ContextAggregator)`（M6 依赖注入，不修改）

#### M11-P2-TASK-002.2: 实现 gatherContext
- [ ] 将 `AgentContextRequest` 转换为 M6 `ContextRequest`
- [ ] 调用 `contextAggregator.gather(context)`（H10，不修改）
- [ ] 返回 `[ContextItem]`（含 source 标注，H10）
- [ ] 处理 `ContextBudget` 截断（防止上下文爆炸）

---

### M11-P2-TASK-003: 实现 CodeArtsAgentContextAdapter（CodeArts 路径）

**任务描述**：在 Application 层实现 CodeArts Agent 路径的上下文桥接，经 M9 `PublicProtocolSurfaceProvider`（H22）注入上下文，不直接访问宿主内部。

**输入**：TASK-001 协议 + M9 `PublicProtocolSurfaceProvider`

**输出**：`CodeArtsAgentContextAdapter` 实现文件

**依赖**：M11-P2-TASK-001

**验收标准**：
- 经 M9 `PublicProtocolSurfaceProvider`（H22，不修改）
- 不直接访问宿主内部（H22）
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeApplication/GAIBridge/CodeArtsAgentContextAdapter.swift` — `CodeArtsAgentContextAdapter` 实现

**复用既有能力**：M9 `PublicProtocolSurfaceProvider`（H22，不修改）

**硬约束映射**：H22

#### M11-P2-TASK-003.1: 实现 CodeArtsAgentContextAdapter 依赖注入
- [ ] 定义 `CodeArtsAgentContextAdapter` final class，`@unchecked Sendable`
- [ ] `init(surfaceProvider: PublicProtocolSurfaceProvider, contextAggregator: ContextAggregator)`（M9 + M6 依赖注入，不修改）

#### M11-P2-TASK-003.2: 实现 gatherContext（经 PublicProtocolSurface）
- [ ] 经 `surfaceProvider.surface(for: .codeArts)` 获取 `PublicProtocolSurface`（H22）
- [ ] 经受限 API 面注入上下文（不直接访问宿主内部，H22）
- [ ] 返回 `[ContextItem]`（含 source 标注，H10）
- [ ] 处理 `ContextBudget` 截断

---

### M11-P2-TASK-004: P2 单元测试

**任务描述**：为 P2 的协议与实现编写单元测试，覆盖 G-AI 路径、CodeArts 路径、H10/H22 验收。

**输入**：TASK-002 + TASK-003 实现

**输出**：P2 测试文件

**依赖**：M11-P2-TASK-003

**验收标准**：
- 所有新增测试 PASS
- M0-M10 既有 1103 tests 全部 PASS（回归）
- H10 / H22 验收测试 PASS

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/AgentContextBridgeTests.swift`

**硬约束映射**：H10 / H22

#### M11-P2-TASK-004.1: AgentContextBridge 协议测试
- [ ] 测试 `gatherContext` 返回 `[ContextItem]`
- [ ] 测试 `ContextBudget` 截断生效

#### M11-P2-TASK-004.2: G-AI 路径测试（经 ContextAggregator）
- [ ] `testH10_gaiContextViaContextAggregator`：断言 G-AI 路径经 M6 `ContextAggregator.gather`
- [ ] 断言每个 `ContextItem` 含 `source` 标注（H10）

#### M11-P2-TASK-004.3: CodeArts 路径测试（经 PublicProtocolSurface）
- [ ] `testH22_codeArtsContextViaPublicProtocolSurface`：断言 CodeArts 路径经 M9 `PublicProtocolSurface`
- [ ] 断言不直接访问宿主内部（H22）

#### M11-P2-TASK-004.4: 运行测试并验证回归
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P2 新增 tests PASS
- [ ] `arch-check.sh` → x86_64

---

### M11-P2-TASK-005: P2 Exit Gate 验证

**任务描述**：执行 P2 Exit Gate 全部验收检查。

**输入**：TASK-001 ~ TASK-004 全部完成

**输出**：P2 Exit Gate 通过证据

**依赖**：M11-P2-TASK-004

**验收标准**（Exit Gate）：
- [ ] `swift build` → 0 errors
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P2 新增 tests PASS
- [ ] `arch-check.sh` → x86_64（H1）
- [ ] M10 `81bb91f` / M9 `23579c2` 源文件 0 modified
- [ ] H10 / H22 / H28 验收 PASS
- [ ] PM Gate Review 通过，授权 P3

**硬约束映射**：H1 / H10 / H22 / H28

---

## 5. M11-P3: Agent ↔ MCP / Skills / Rules

**Phase 目标**：定义 `AIToolInvocationBridge`，确保 AI 生成的工具调用经 M7 `ToolRegistry`（H28-2）+ M8 既有接入路径，Rules 约束对 AI 生成的 Plan 同样适用（H17）。

**Phase 前置**：P2 Exit Gate PASS + PM 授权 P3

**Phase 硬约束**：H15 / H16 / H17 / H28-2 / H28-7 / H28-8 / H28-9

**Phase 不修改**：M7 / M8 任何源文件

### M11-P3-TASK-001: 定义 AIToolInvocationBridge 协议与值类型

**任务描述**：在 Domain 层定义 `AIToolInvocationBridge` protocol 及 `AIToolCallRequest` / `AIToolCallResult` 值类型。

**输入**：`m11_design.md` §2.2.2.3 接口签名

**输出**：`AIToolInvocationBridge` 协议定义文件

**依赖**：M11-P2-TASK-005（P2 Exit Gate PASS）

**验收标准**：
- `AIToolInvocationBridge` protocol 为 `Sendable`
- `AIToolCallRequest` / `AIToolCallResult` 为 `Sendable + Codable + Equatable`
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeDomain/GAIBridge/AIToolInvocationBridge.swift` — `AIToolInvocationBridge` protocol + `AIToolCallRequest` / `AIToolCallResult`

**复用既有能力**：M7 `ToolID` / `ToolArguments` / `ToolOutput` / `AgentSessionID` / `AuthorizationDecision` / `AuditRecordID`（引用，不修改）

**硬约束映射**：H28-2

#### M11-P3-TASK-001.1: 定义 AIToolCallRequest 值类型
- [ ] 定义 `AIToolCallRequest` struct（toolID / arguments / source / sessionID），`Sendable + Codable + Equatable`
- [ ] `source: AgentContextSource` 区分 AI vs 人类发起

#### M11-P3-TASK-001.2: 定义 AIToolCallResult 值类型
- [ ] 定义 `AIToolCallResult` struct（toolOutput / auditRecordID / authorizationDecision），`Sendable + Codable + Equatable`

#### M11-P3-TASK-001.3: 定义 AIToolInvocationBridge protocol
- [ ] 定义 `AIToolInvocationBridge: Sendable` protocol
- [ ] 定义 `invoke(_ request: AIToolCallRequest) async throws -> AIToolCallResult`
- [ ] 异常映射：`AIToolError.unknownTool` → `M11-P3-001`（H28-2），`authorizationDenied` → `M11-P3-002`（H28-3），`executionFailed` → `M11-P3-003`

#### M11-P3-TASK-001.4: 前置定义 AICapabilityAuthorizationBridge protocol（仅签名，P4 实现）
- [ ] 在 `Sources/AppKCodeDomain/GAIBridge/AICapabilityAuthorizationBridge.swift` 中前置定义 `AICapabilityAuthorizationBridge: Sendable` protocol（仅 `authorize` 方法签名）
- [ ] 前置定义 `AICapabilityRequest` 占位（P4 阶段补充实现）
- [ ] 注释标注：`// M11-P4 将补充 AICapabilityAuthorizationBridgeImpl 实现`

---

### M11-P3-TASK-002: 实现 AIToolInvocationBridgeImpl

**任务描述**：在 Application 层实现 `AIToolInvocationBridgeImpl`，将 AI 生成的工具调用经 M7 `ToolRegistry.resolve` → 授权 → `ActionExecutor.execute` → 审计。

**输入**：TASK-001 协议 + M7 `ToolRegistry` / `ActionExecutor` + P4 `AICapabilityAuthorizationBridge`（protocol）+ P5 `AIAuditBridge`（protocol）

**输出**：`AIToolInvocationBridgeImpl` 实现文件

**依赖**：M11-P3-TASK-001

**验收标准**：
- 工具调用经 M7 `ToolRegistry.resolve`（H28-2）
- 未知工具拒绝（H28-2）
- 工具为 Capability → `AICapabilityAuthorizationBridge.authorize`（P4）
- 普通 Agent 工具 → M7 `AuthorizationGate.authorize`（H12，H28-3）
- 经 `ActionExecutor.execute`（H13）
- 经 `AIAuditBridge.record`（H28-6）
- 不存在 AI → Shell / Git / File 直接执行路径（H28-7/H28-8/H28-9）
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeApplication/GAIBridge/AIToolInvocationBridgeImpl.swift` — `AIToolInvocationBridgeImpl` 实现

**复用既有能力**：
- M7 `ToolRegistry.resolve` / `ActionExecutor.execute`（H13，不修改）
- M7 `AuthorizationGate.authorize`（H12，不修改）
- M8 `MCPToolAdapter` / `SkillExecutor` / `RuleEnforcer`（H15/H16/H17，不修改）

**硬约束映射**：H13 / H15 / H16 / H17 / H28-2 / H28-3 / H28-7 / H28-8 / H28-9

#### M11-P3-TASK-002.1: 实现 AIToolInvocationBridgeImpl 依赖注入
- [ ] 定义 `AIToolInvocationBridgeImpl` final class，`@unchecked Sendable`
- [ ] `init(toolRegistry: ToolRegistry, actionExecutor: ActionExecutor, authBridge: AICapabilityAuthorizationBridge?, auditBridge: AIAuditBridge?)`（authBridge / auditBridge 可选，P4/P5 后注入）

#### M11-P3-TASK-002.2: 实现 invoke 主流程
- [ ] `ToolRegistry.resolve(request.toolID)` → 未知工具抛 `AIToolError.unknownTool`（H28-2）
- [ ] 判断工具是否为 Capability（经 ToolRegistry schema 或 toolID 前缀判断）
- [ ] 工具为 Capability → `authBridge.authorize`（P4，H28-4/H28-5）
- [ ] 普通 Agent 工具 → M7 `AuthorizationGate.authorize`（H12，H28-3，由 ActionExecutor 内部保障）
- [ ] 授权通过 → `ActionExecutor.execute`（H13）
- [ ] 授权拒绝 → 抛 `AIToolError.authorizationDenied`（H28-3）

#### M11-P3-TASK-002.3: 实现审计接入
- [ ] 如 `auditBridge` 非空，记录 `aiToolCallRequested` / `aiToolCallCompleted` / `aiToolCallFailed` 审计事件
- [ ] 返回 `AIToolCallResult`（含 `auditRecordID`，可追溯）

#### M11-P3-TASK-002.4: 验证无 bypass 路径
- [ ] 源码审查：`AIToolInvocationBridgeImpl` 仅经 `ToolRegistry` + `ActionExecutor`，无 `Process.execute` 直接调用（H28-7）
- [ ] 源码审查：Git 操作仅经 M7 `GitTools`（`ToolRegistry` 注册），无 `git` 命令直接调用（H28-8）
- [ ] 源码审查：文件写入仅经 M7 `FileWriteTool`（high → Approval），无 `FileHandle.write` 直接调用（H28-9）

#### M11-P3-TASK-002.5: Rules 约束对 AI 生成的 Plan 适用
- [ ] 验证 M8 `RuleEnforcer` 对 AI 生成的 Plan 同样适用（H17，由 M7 Orchestrator 内部保障，不修改）
- [ ] 验证 MCP 工具经 `MCPToolAdapter`（H15，不修改）
- [ ] 验证 Skill 经 `SkillExecutor`（H16，不修改）

---

### M11-P3-TASK-003: P3 单元测试与 H28 验收测试

**任务描述**：为 P3 编写单元测试与 H28-2/H28-7/H28-8/H28-9 验收测试。

**输入**：TASK-002 实现

**输出**：P3 测试文件

**依赖**：M11-P3-TASK-002

**验收标准**：
- 所有新增测试 PASS
- H28-2 / H28-7 / H28-8 / H28-9 验收测试 PASS

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/AIToolInvocationBridgeTests.swift`
- `Tests/AppKCodeApplicationTests/GAIBridge/AIToolInvocationH28Tests.swift`

**硬约束映射**：H28-2 / H28-7 / H28-8 / H28-9

#### M11-P3-TASK-003.1: AIToolInvocationBridge 单元测试
- [ ] 测试已知工具经 `ToolRegistry.resolve` 成功调用
- [ ] 测试未知工具抛 `AIToolError.unknownTool`
- [ ] 测试授权拒绝抛 `AIToolError.authorizationDenied`
- [ ] 测试返回 `AIToolCallResult` 含 `auditRecordID`

#### M11-P3-TASK-003.2: H28-2 验收测试
- [ ] `testH28_2_aiToolCallViaToolRegistry`：断言 AI 工具调用经 M7 `ToolRegistry.resolve`
- [ ] 断言未知工具被拒绝

#### M11-P3-TASK-003.3: H28-7 验收测试
- [ ] `testH28_7_noAIDirectShellExecution`：断言不存在 AI → Shell 直接执行路径
- [ ] 源码审查 + 测试：`AIToolInvocationBridgeImpl` 无 `Process.execute` 直接调用

#### M11-P3-TASK-003.4: H28-8 验收测试
- [ ] `testH28_8_noAIDirectGitExecution`：断言不存在 AI → Git 直接执行路径
- [ ] 源码审查 + 测试：Git 操作仅经 M7 `GitTools`

#### M11-P3-TASK-003.5: H28-9 验收测试
- [ ] `testH28_9_noAIDirectFileWrite`：断言不存在 AI → File 直接写入路径
- [ ] 源码审查 + 测试：文件写入仅经 M7 `FileWriteTool`（high → Approval）

#### M11-P3-TASK-003.6: 运行测试并验证回归
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P3 新增 tests PASS
- [ ] `arch-check.sh` → x86_64

---

### M11-P3-TASK-004: P3 Exit Gate 验证

**任务描述**：执行 P3 Exit Gate 全部验收检查。

**输入**：TASK-001 ~ TASK-003 全部完成

**输出**：P3 Exit Gate 通过证据

**依赖**：M11-P3-TASK-003

**验收标准**（Exit Gate）：
- [ ] `swift build` → 0 errors
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P3 新增 tests PASS
- [ ] `arch-check.sh` → x86_64（H1）
- [ ] M10 `81bb91f` / M9 `23579c2` 源文件 0 modified
- [ ] H15 / H16 / H17 / H28-2 / H28-7 / H28-8 / H28-9 验收 PASS
- [ ] PM Gate Review 通过，授权 P4

**硬约束映射**：H1 / H15 / H16 / H17 / H28-2 / H28-7 / H28-8 / H28-9

---

## 6. M11-P4: AI Capability Authorization

**Phase 目标**：实现 H28 授权桥接 `AICapabilityAuthorizationBridge`，将 AI Capability 调用经 M9 `enforceContract`（H21）→ M9 `ExtensionAuthorizationIntegration`（H20）→ M7 `AuthorizationGate`（H12）。

**Phase 前置**：P3 Exit Gate PASS + PM 授权 P4

**Phase 硬约束**：H2 / H12 / H20 / H21 / H28-3 / H28-4 / H28-5

**Phase 不修改**：M0 / M7 / M9 任何源文件

### M11-P4-TASK-001: 定义 AICapabilityAuthorizationBridge 协议与值类型

**任务描述**：在 Domain 层定义 `AICapabilityAuthorizationBridge` protocol 及 `AICapabilityRequest` 值类型（补充 P3 前置定义的占位）。

**输入**：`m11_design.md` §2.2.2.4 接口签名 + P3 前置定义的 protocol 占位

**输出**：`AICapabilityAuthorizationBridge` 协议完整定义

**依赖**：M11-P3-TASK-004（P3 Exit Gate PASS）

**验收标准**：
- `AICapabilityAuthorizationBridge` protocol 为 `Sendable`
- `AICapabilityRequest` 为 `Sendable + Codable + Equatable`
- `swift build` → 0 errors

**涉及文件**（修改 P3 前置定义的占位文件）：
- `Sources/AppKCodeDomain/GAIBridge/AICapabilityAuthorizationBridge.swift` — 补充完整 protocol + `AICapabilityRequest`

**复用既有能力**：M9 `CapabilityID` / `ExtensionID` / `AnyCodableValue` + M7 `AgentSessionID` / `AuthorizationDecision`（引用，不修改）

**硬约束映射**：H28-4 / H28-5

#### M11-P4-TASK-001.1: 定义 AICapabilityRequest 值类型
- [ ] 定义 `AICapabilityRequest` struct（capabilityID / extensionID / input / source / sessionID），`Sendable + Codable + Equatable`

#### M11-P4-TASK-001.2: 补充 AICapabilityAuthorizationBridge protocol
- [ ] 补充 `authorize(_ request: AICapabilityRequest) async throws -> AuthorizationDecision` 方法签名
- [ ] 异常映射：`AICapabilityError.noContract` → `M11-P4-001`（H28-4），`extensionDenied` → `M11-P4-002`（H28-5），`highRiskRejected` → `M11-P4-003`（H28-3）

---

### M11-P4-TASK-002: 实现 AICapabilityAuthorizationBridgeImpl

**任务描述**：在 Application 层实现 `AICapabilityAuthorizationBridgeImpl`，将 AI Capability 调用经 M9 Contract → M9 ExtensionAuth → M7 AuthorizationGate。

**输入**：TASK-001 协议 + M9 `CapabilityContractRegistry` / `ExtensionAuthorizationIntegration` + M7 `AuthorizationGate`

**输出**：`AICapabilityAuthorizationBridgeImpl` 实现文件

**依赖**：M11-P4-TASK-001

**验收标准**：
- 无 Contract 拒绝执行（H21，H28-4）
- 默认拒绝 + 高危二次审批（H20，H28-5）
- 高危 → M7 `AuthorizationGate.authorize`（H12，H28-3）→ `ApprovalService.requestApproval`（H2）
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeApplication/GAIBridge/AICapabilityAuthorizationBridgeImpl.swift` — `AICapabilityAuthorizationBridgeImpl` 实现

**复用既有能力**：
- M9 `CapabilityContractRegistry.enforceContract`（H21，不修改）
- M9 `ExtensionAuthorizationIntegration.authorize`（H20，不修改）
- M7 `AuthorizationGate.authorize`（H12，不修改）
- M0 `ApprovalService.requestApproval`（H2，不修改）

**硬约束映射**：H2 / H12 / H20 / H21 / H28-3 / H28-4 / H28-5

#### M11-P4-TASK-002.1: 实现 AICapabilityAuthorizationBridgeImpl 依赖注入
- [ ] 定义 `AICapabilityAuthorizationBridgeImpl` final class，`@unchecked Sendable`
- [ ] `init(contractRegistry: CapabilityContractRegistry, authIntegration: ExtensionAuthorizationIntegration, authGate: AuthorizationGate)`（M9 + M7 依赖注入，不修改）

#### M11-P4-TASK-002.2: 实现 authorize 主流程
- [ ] `contractRegistry.enforceContract(capabilityID, input)` → 无 Contract 抛 `AICapabilityError.noContract`（H21，H28-4）
- [ ] `authIntegration.authorize(extensionID, capability, permission)` → 默认拒绝（H20，H28-5）
- [ ] 高危 → M7 `authGate.authorize`（H12，H28-3）→ `ApprovalService.requestApproval`（H2，由 AuthorizationGateImpl 内部保障）

#### M11-P4-TASK-002.3: 验证不修改既有组件
- [ ] `git diff` 校验 M0 / M7 / M9 源文件 0 modified
- [ ] 验证不创建第二套授权系统（H12，H28）

---

### M11-P4-TASK-003: P4 单元测试与 H28 验收测试

**任务描述**：为 P4 编写单元测试与 H28-3/H28-4/H28-5 验收测试。

**输入**：TASK-002 实现

**输出**：P4 测试文件

**依赖**：M11-P4-TASK-002

**验收标准**：
- 所有新增测试 PASS
- H28-3 / H28-4 / H28-5 验收测试 PASS

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/AICapabilityAuthorizationBridgeTests.swift`

**硬约束映射**：H2 / H12 / H20 / H21 / H28-3 / H28-4 / H28-5

#### M11-P4-TASK-003.1: AICapabilityAuthorizationBridge 单元测试
- [ ] 测试有 Contract + 授权通过 → `AuthorizationDecision.allowed`
- [ ] 测试无 Contract → 抛 `AICapabilityError.noContract`
- [ ] 测试 Extension 拒绝 → 抛 `AICapabilityError.extensionDenied`
- [ ] 测试高危拒绝 → 抛 `AICapabilityError.highRiskRejected`

#### M11-P4-TASK-003.2: H28-3 验收测试
- [ ] `testH28_3_aiHighRiskViaAuthorizationGate`：断言 AI 高危操作经 M7 `AuthorizationGate` 强制审批
- [ ] 断言高危操作触发 `ApprovalService.requestApproval`（H2 不可 bypass）

#### M11-P4-TASK-003.3: H28-4 验收测试
- [ ] `testH28_4_aiCapabilityViaEnforceContract`：断言 AI Capability 调用经 M9 `enforceContract`
- [ ] 断言无 Contract 拒绝执行

#### M11-P4-TASK-003.4: H28-5 验收测试
- [ ] `testH28_5_aiExtensionViaExtensionAuthorizationIntegration`：断言 AI Extension 调用经 M9 `ExtensionAuthorizationIntegration`
- [ ] 断言默认拒绝 + 高危二次审批

#### M11-P4-TASK-003.5: 运行测试并验证回归
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P4 新增 tests PASS
- [ ] `arch-check.sh` → x86_64

---

### M11-P4-TASK-004: P4 Exit Gate 验证

**任务描述**：执行 P4 Exit Gate 全部验收检查。

**输入**：TASK-001 ~ TASK-003 全部完成

**输出**：P4 Exit Gate 通过证据

**依赖**：M11-P4-TASK-003

**验收标准**（Exit Gate）：
- [ ] `swift build` → 0 errors
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P4 新增 tests PASS
- [ ] `arch-check.sh` → x86_64（H1）
- [ ] M10 `81bb91f` / M9 `23579c2` / M0 源文件 0 modified
- [ ] H2 / H12 / H20 / H21 / H28-3 / H28-4 / H28-5 验收 PASS
- [ ] PM Gate Review 通过，授权 P5

**硬约束映射**：H1 / H2 / H12 / H20 / H21 / H28-3 / H28-4 / H28-5

---

## 7. M11-P5: AI Tool Execution + Audit

**Phase 目标**：实现 H28 审计桥接 `AIAuditBridge` + 扩展 `AuditTarget` 枚举（追加 `aiInference` / `gaiRuntime` / `aiToolCall` case），将 AI 推理/工具调用/流程驱动审计接入 M7 `AuditService`（H14）。

**Phase 前置**：P4 Exit Gate PASS + PM 授权 P5

**Phase 硬约束**：H14 / H18 / H23 / H28-6 / H28-10

**Phase 不修改**：M7 `AuditServiceImpl` / `AuditLogStore` / `AgentAuditRecord` 核心结构（仅扩展 `AuditTarget` 枚举 case）

### M11-P5-TASK-001: 定义 AIAuditBridge 协议与值类型

**任务描述**：在 Domain 层定义 `AIAuditBridge` protocol 及 `AIAuditEvent` / `AIAuditEventKind` 值类型（补充 P1 前置定义的占位）。

**输入**：`m11_design.md` §2.2.2.5 接口签名 + P1 前置定义的 protocol 占位

**输出**：`AIAuditBridge` 协议完整定义

**依赖**：M11-P4-TASK-004（P4 Exit Gate PASS）

**验收标准**：
- `AIAuditBridge` protocol 为 `Sendable`
- `AIAuditEvent` / `AIAuditEventKind` 为 `Sendable + Codable + Equatable`
- `swift build` → 0 errors

**涉及文件**（修改 P1 前置定义的占位文件）：
- `Sources/AppKCodeDomain/GAIBridge/AIAuditBridge.swift` — 补充完整 protocol + `AIAuditEvent` / `AIAuditEventKind`

**复用既有能力**：M7 `AuditTarget` / `AgentSessionID` / `AuditRecordID` + `AnyCodableValue` / `ISO8601Timestamp`（引用，不修改）

**硬约束映射**：H14 / H28-6

#### M11-P5-TASK-001.1: 定义 AIAuditEventKind 枚举
- [ ] 定义 `AIAuditEventKind` enum（11 个 case: aiInferenceRequested / aiInferenceCompleted / aiInferenceFailed / gaiWorkflowPhaseStarted / gaiWorkflowPhaseCompleted / gaiWorkflowPhaseFailed / aiToolCallRequested / aiToolCallCompleted / aiToolCallFailed / aiAuthorizationRequested / aiAuthorizationDecision），`String, Sendable, Codable, Equatable`

#### M11-P5-TASK-001.2: 定义 AIAuditEvent 值类型
- [ ] 定义 `AIAuditEvent` struct（kind / target / sessionID / detail / timestamp），`Sendable + Codable + Equatable`
- [ ] `target: AuditTarget`（含 M11 扩展 case，TASK-002 追加）

#### M11-P5-TASK-001.3: 补充 AIAuditBridge protocol
- [ ] 补充 `record(_ event: AIAuditEvent) async throws -> AuditRecordID` 方法签名
- [ ] 异常映射：`AIAuditError.recordFailed` → `M11-P5-001`，`integrityViolation` → `M11-P5-002`（SHA-256 校验失败）

---

### M11-P5-TASK-002: 扩展 AuditTarget 枚举（仅追加 case）

**任务描述**：在 Shared 层扩展 `AuditTarget` 枚举，追加 `aiInference` / `gaiRuntime` / `aiToolCall` case，不修改既有 case 语义。

**输入**：M7 既有 `AuditTarget` 枚举（`Sources/AppKCodeShared/AgentRuntime/AuditTypes.swift`）

**输出**：`AuditTarget` 枚举扩展（仅追加 case）

**依赖**：M11-P5-TASK-001

**验收标准**：
- 仅追加 3 个 case，不修改既有 case 语义
- 不修改 `AgentAuditRecord` 8 字段结构（H14 不变）
- 不修改 `AuditServiceImpl` / `AuditLogStore` 核心实现
- `swift build` → 0 errors
- M7 既有测试全部 PASS（回归）

**涉及文件**（修改，仅追加 case）：
- `Sources/AppKCodeShared/AgentRuntime/AuditTypes.swift` — `AuditTarget` enum 追加 `aiInference(modelEndpoint: String)` / `gaiRuntime(phase: GAIWorkflowPhase)` / `aiToolCall(tool: ToolID)` case

**复用既有能力**：M7 `AuditTarget`（仅扩展，不修改既有 case）

**硬约束映射**：H14 / H23 / H28-6 / H28-10

#### M11-P5-TASK-002.1: 追加 aiInference case
- [ ] 在 `AuditTarget` enum 追加 `case aiInference(modelEndpoint: String)`
- [ ] 验证不修改既有 case 语义

#### M11-P5-TASK-002.2: 追加 gaiRuntime case
- [ ] 在 `AuditTarget` enum 追加 `case gaiRuntime(phase: GAIWorkflowPhase)`
- [ ] 验证不修改既有 case 语义

#### M11-P5-TASK-002.3: 追加 aiToolCall case
- [ ] 在 `AuditTarget` enum 追加 `case aiToolCall(tool: ToolID)`
- [ ] 验证不修改既有 case 语义

#### M11-P5-TASK-002.4: 验证 AgentAuditRecord 结构不变
- [ ] 验证 `AgentAuditRecord` 8 字段结构不变（H14 不变）
- [ ] 验证 `AuditServiceImpl` / `AuditLogStore` 核心实现不修改
- [ ] `swift test` → M7 既有审计测试全部 PASS（回归）

---

### M11-P5-TASK-003: 实现 AIAuditBridgeImpl

**任务描述**：在 Application 层实现 `AIAuditBridgeImpl`，将 AI 审计事件经 M7 `AuditService.record`（H14）记录，单一审计入口，无第二套审计系统（H23，H28-10）。

**输入**：TASK-001 协议 + TASK-002 AuditTarget 扩展 + M7 `AuditService`

**输出**：`AIAuditBridgeImpl` 实现文件

**依赖**：M11-P5-TASK-002

**验收标准**：
- 经 M7 `AuditService.record`（H14，不修改实现）
- 审计记录含 8 字段 + SHA-256（H14 不变）
- JSONL 追加写（不可篡改）
- 单一审计入口（H23 不变，H28-10）
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeApplication/GAIBridge/AIAuditBridgeImpl.swift` — `AIAuditBridgeImpl` 实现

**复用既有能力**：
- M7 `AuditService.record`（H14，不修改实现）
- M7 `AuditLogStore.append`（JSONL 追加写，不修改）

**硬约束映射**：H14 / H23 / H28-6 / H28-10

#### M11-P5-TASK-003.1: 实现 AIAuditBridgeImpl 依赖注入
- [ ] 定义 `AIAuditBridgeImpl` final class，`@unchecked Sendable`
- [ ] `init(auditService: AuditService)`（M7 依赖注入，不修改）

#### M11-P5-TASK-003.2: 实现 record
- [ ] 将 `AIAuditEvent` 转换为 M7 `AgentAuditRecord`（8 字段 + SHA-256，H14）
- [ ] 调用 `auditService.record`（H14，不修改）
- [ ] 返回 `AuditRecordID`

#### M11-P5-TASK-003.3: 验证不创建第二套审计系统
- [ ] 源码审查：`AIAuditBridgeImpl` 仅经 M7 `AuditService.record`，不创建新 `AuditService` 实现（H23，H28-10）
- [ ] 验证 JSONL 追加写（不可篡改）

---

### M11-P5-TASK-004: P5 单元测试与 H28 验收测试

**任务描述**：为 P5 编写单元测试与 H28-6/H28-10 验收测试。

**输入**：TASK-003 实现

**输出**：P5 测试文件

**依赖**：M11-P5-TASK-003

**验收标准**：
- 所有新增测试 PASS
- H28-6 / H28-10 验收测试 PASS
- M7 既有审计测试全部 PASS（回归）

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/AIAuditBridgeTests.swift`

**硬约束映射**：H14 / H18 / H23 / H28-6 / H28-10

#### M11-P5-TASK-004.1: AIAuditBridge 单元测试
- [ ] 测试 `record` 返回 `AuditRecordID`
- [ ] 测试 `AIAuditEvent` 各 kind 正确记录
- [ ] 测试 `AuditTarget.aiInference` / `gaiRuntime` / `aiToolCall` 新 case 正确记录

#### M11-P5-TASK-004.2: H28-6 验收测试
- [ ] `testH28_6_allAIActionsViaAuditService`：断言所有 AI 动作经 M7 `AuditService` 审计
- [ ] 断言审计记录含 8 字段 + SHA-256（H14）
- [ ] 断言 `AuditTarget.aiInference` / `gaiRuntime` / `aiToolCall` 覆盖

#### M11-P5-TASK-004.3: H28-10 验收测试
- [ ] `testH28_10_noSecondAuditSystem`：断言不存在第二套审计系统
- [ ] 源码审查：单一 `AuditService` 入口，M11 仅扩展 `AuditTarget` 枚举

#### M11-P5-TASK-004.4: 回归测试
- [ ] `swift test` → M7 既有审计测试全部 PASS（H14/H18/H23 回归）
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P5 新增 tests PASS
- [ ] `arch-check.sh` → x86_64

---

### M11-P5-TASK-005: P5 Exit Gate 验证

**任务描述**：执行 P5 Exit Gate 全部验收检查。

**输入**：TASK-001 ~ TASK-004 全部完成

**输出**：P5 Exit Gate 通过证据

**依赖**：M11-P5-TASK-004

**验收标准**（Exit Gate）：
- [ ] `swift build` → 0 errors
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P5 新增 tests PASS
- [ ] `arch-check.sh` → x86_64（H1）
- [ ] M10 `81bb91f` / M9 `23579c2` 源文件 0 modified（`AuditTarget` 枚举追加 case 为允许的例外）
- [ ] H14 / H18 / H23 / H28-6 / H28-10 验收 PASS
- [ ] PM Gate Review 通过，授权 P6

**硬约束映射**：H1 / H14 / H18 / H23 / H28-6 / H28-10

---

## 8. M11-P6: CodeArts Agent Integration

**Phase 目标**：实现 `CodeArtsAgentOrchestrator`，将 CodeArts Agent 工作流经 M9 `CapabilityAppService.invokeCapability`（H19 全链路）集成，复用 M10 `VSCodeExtensionHostAdapter` / `JetBrainsPluginHostAdapter`。

**Phase 前置**：P5 Exit Gate PASS + PM 授权 P6

**Phase 硬约束**：H19 / H20 / H21 / H22 / H23 / H24 / H25 / H26 / H27 / H28

**Phase 不修改**：M9 / M10 任何源文件

**Phase 不宣称**：所有 CodeArts 插件完全兼容

### M11-P6-TASK-001: 定义 CodeArtsAgentOrchestrator 与值类型

**任务描述**：在 Application 层定义 `CodeArtsAgentOrchestrator` class 及 `CodeArtsAgentRequest` / `CodeArtsAgentResult` / `CodeArtsAgentPhaseResult` / `CodeArtsAdapterDeepeningPolicy` 值类型。

**输入**：`m11_design.md` §2.2.2.6 接口签名

**输出**：`CodeArtsAgentOrchestrator` 定义文件

**依赖**：M11-P5-TASK-005（P5 Exit Gate PASS）

**验收标准**：
- `CodeArtsAgentOrchestrator` 为 `final class + @unchecked Sendable`
- 所有值类型为 `Sendable + Codable + Equatable`
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeApplication/GAIBridge/CodeArtsAgentOrchestrator.swift` — `CodeArtsAgentOrchestrator` + `CodeArtsAgentRequest` / `CodeArtsAgentResult` / `CodeArtsAgentPhaseResult` / `CodeArtsAgentStatus` / `CodeArtsAdapterDeepeningPolicy`

**复用既有能力**：M9 `CapabilityID` / `ExtensionID` + M7 `AgentSessionID` / `AuditRecordID`（引用，不修改）

**硬约束映射**：H19 / H28

#### M11-P6-TASK-001.1: 定义 CodeArtsAdapterDeepeningPolicy 枚举
- [ ] 定义 `CodeArtsAdapterDeepeningPolicy` enum（2 个 case: evaluateOnly / deepen），`String, Sendable, Codable, Equatable`

#### M11-P6-TASK-001.2: 定义 CodeArtsAgentRequest / CodeArtsAgentResult 值类型
- [ ] 定义 `CodeArtsAgentRequest` struct（extensionID / workflow / contextRequest / sessionID），`Sendable + Codable + Equatable`
- [ ] 定义 `CodeArtsAgentPhaseResult` struct（phase / result / auditRecordID / timestamp），`Sendable + Codable + Equatable`
- [ ] 定义 `CodeArtsAgentStatus` enum（pending / inProgress / completed / failed / cancelled），`String, Sendable, Codable, Equatable`
- [ ] 定义 `CodeArtsAgentResult` struct（phaseResults / auditRecordIDs / status），`Sendable + Codable + Equatable`

#### M11-P6-TASK-001.3: 定义 CodeArtsAgentOrchestrator class
- [ ] 定义 `CodeArtsAgentOrchestrator` final class，`@unchecked Sendable`
- [ ] `init(capabilityAppService: CapabilityAppService, contextBridge: AgentContextBridge, auditBridge: AIAuditBridge, deepeningPolicy: CodeArtsAdapterDeepeningPolicy)`
- [ ] 定义 `executeWorkflow(_ request: CodeArtsAgentRequest) async throws -> CodeArtsAgentResult`
- [ ] 异常映射：`CodeArtsAgentError.incompatibleExtension` → `M11-P6-001`（H24），`processCrashed` → `M11-P6-002`（H25），`resourceLimitExceeded` → `M11-P6-003`（H27）

---

### M11-P6-TASK-002: 实现 CodeArtsAgentOrchestrator

**任务描述**：实现 `executeWorkflow`，将 CodeArts Agent 工作流经 M9 `CapabilityAppService.invokeCapability`（H19 全链路）执行。

**输入**：TASK-001 定义 + M9 `CapabilityAppService` + P2 `AgentContextBridge` + P5 `AIAuditBridge`

**输出**：`CodeArtsAgentOrchestrator` 实现

**依赖**：M11-P6-TASK-001

**验收标准**：
- 所有 Capability 调用经 H19 全链路（Contract → Auth → Exec → Audit）
- 进程隔离（H25）+ 资源限制（H27）生效
- CodeArts Agent 经 `PublicProtocolSurface`（H22），不直接访问宿主内部
- `swift build` → 0 errors

**涉及文件**（修改 TASK-001 文件）：
- `Sources/AppKCodeApplication/GAIBridge/CodeArtsAgentOrchestrator.swift` — 补充 `executeWorkflow` 实现

**复用既有能力**：
- M9 `CapabilityAppService.invokeCapability`（H19/H20/H21/H22/H23，不修改）
- M10 `VSCodeExtensionHostAdapter` / `JetBrainsPluginHostAdapter`（H25/H26/H27，不修改）
- M9 `VersionNegotiationService`（H24，不修改）

**硬约束映射**：H19 / H20 / H21 / H22 / H23 / H24 / H25 / H26 / H27 / H28

#### M11-P6-TASK-002.1: 实现 executeWorkflow 主流程
- [ ] `contextBridge.gatherContext(request.contextRequest)`（P2，经 `PublicProtocolSurface` H22）
- [ ] `capabilityAppService.invokeCapability(capabilityID, extensionID, input, sessionID)`（H19 全链路）
- [ ] 进程隔离由 M10 `ExtensionHostProcessManager`（H25）保障（不修改）
- [ ] 资源限制由 M10 `ExtensionResourceLimiter`（H27）保障（不修改）
- [ ] 版本协商由 M9 `VersionNegotiationService`（H24）保障（不修改）

#### M11-P6-TASK-002.2: 实现审计接入
- [ ] 经 `auditBridge.record` 记录 CodeArts Agent 各阶段审计事件
- [ ] 返回 `CodeArtsAgentResult`（含 `auditRecordIDs`，可追溯）

#### M11-P6-TASK-002.3: CodeArts Adapter 深化策略评估
- [ ] `deepeningPolicy == .evaluateOnly`（默认）：仅评估 CodeArts Adapter 是否深化，不强制深化
- [ ] `deepeningPolicy == .deepen`：P6 Gate Review 授权后深化（如需要，需 PM 单独授权）
- [ ] 不宣称"所有 CodeArts 插件完全兼容"

#### M11-P6-TASK-002.4: 验证不修改既有组件
- [ ] `git diff` 校验 M9 / M10 源文件 0 modified
- [ ] 验证不创建第二套授权/审计系统

---

### M11-P6-TASK-003: P6 单元测试与 H19-H24 验收测试

**任务描述**：为 P6 编写单元测试与 H19-H24 验收测试。

**输入**：TASK-002 实现

**输出**：P6 测试文件

**依赖**：M11-P6-TASK-002

**验收标准**：
- 所有新增测试 PASS
- H19 / H20 / H21 / H22 / H23 / H24 验收测试 PASS

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/CodeArtsAgentOrchestratorTests.swift`

**硬约束映射**：H19 / H20 / H21 / H22 / H23 / H24 / H25 / H26 / H27 / H28

#### M11-P6-TASK-003.1: CodeArtsAgentOrchestrator 单元测试
- [ ] 测试 `executeWorkflow` 返回 `CodeArtsAgentResult`
- [ ] 测试 `evaluateOnly` 策略不深化 Adapter
- [ ] 测试不兼容 Extension 抛 `CodeArtsAgentError.incompatibleExtension`（H24）

#### M11-P6-TASK-003.2: H19 验收测试
- [ ] `testH19_codeArtsAgentFullChain`：断言 CodeArts Agent 经 H19 全链路（Contract → Auth → Exec → Audit）

#### M11-P6-TASK-003.3: H20-H24 验收测试
- [ ] `testH20_extensionAuthorization`：断言 Extension 授权默认拒绝 + 高危二次审批
- [ ] `testH21_capabilityContract`：断言 Capability Contract 强制
- [ ] `testH22_adapterIsolation`：断言 CodeArts Agent 经 `PublicProtocolSurface`，不直接访问宿主内部
- [ ] `testH23_compatibilityAudit`：断言审计经 M9 `ExtensionAuditIntegration` → M7
- [ ] `testH24_versionNegotiation`：断言版本协商发生，不兼容拒绝

#### M11-P6-TASK-003.4: H25-H27 验收测试
- [ ] `testH25_processIsolation`：断言进程隔离生效（M10 `ExtensionHostProcessManager`）
- [ ] `testH26_apiSurfaceBoundary`：断言 API Surface Boundary 生效（M10）
- [ ] `testH27_resourceLimit`：断言资源限制生效（M10 `ExtensionResourceLimiter`）

#### M11-P6-TASK-003.5: 运行测试并验证回归
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P6 新增 tests PASS
- [ ] `arch-check.sh` → x86_64

---

### M11-P6-TASK-004: P6 Exit Gate 验证

**任务描述**：执行 P6 Exit Gate 全部验收检查。

**输入**：TASK-001 ~ TASK-003 全部完成

**输出**：P6 Exit Gate 通过证据

**依赖**：M11-P6-TASK-003

**验收标准**（Exit Gate）：
- [ ] `swift build` → 0 errors
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P6 新增 tests PASS
- [ ] `arch-check.sh` → x86_64（H1）
- [ ] M10 `81bb91f` / M9 `23579c2` 源文件 0 modified
- [ ] H19 / H20 / H21 / H22 / H23 / H24 / H25 / H26 / H27 / H28 验收 PASS
- [ ] 不宣称"所有 CodeArts 插件完全兼容"
- [ ] PM Gate Review 通过，授权 P7

**硬约束映射**：H1 / H19-H28

---

## 9. M11-P7: End-to-End Agent Runtime

**Phase 目标**：实现 `GAIIntegrationOrchestrator` 端到端编排，串联 P1-P6 全部桥接，验证 H28-1 ~ H28-10 全链路。

**Phase 前置**：P6 Exit Gate PASS + PM 授权 P7

**Phase 硬约束**：H1-H28 全部

**Phase 不修改**：M0-M10 任何源文件

### M11-P7-TASK-001: 实现 GAIIntegrationOrchestrator

**任务描述**：在 Application 层实现 `GAIIntegrationOrchestrator`，串联 P1-P6 全部桥接，提供端到端集成入口。

**输入**：P1 `GAIRuntimeBridge` + P2 `AgentContextBridge` + P3 `AIToolInvocationBridge` + P4 `AICapabilityAuthorizationBridge` + P5 `AIAuditBridge` + P6 `CodeArtsAgentOrchestrator`

**输出**：`GAIIntegrationOrchestrator` 实现文件

**依赖**：M11-P6-TASK-004（P6 Exit Gate PASS）

**验收标准**：
- `GAIIntegrationOrchestrator` 为 `final class + @unchecked Sendable`
- `runGAIIntegration` 串联 G-AI 全链路
- `runCodeArtsIntegration` 串联 CodeArts Agent 全链路
- `swift build` → 0 errors

**涉及文件**（新增）：
- `Sources/AppKCodeApplication/GAIBridge/GAIIntegrationOrchestrator.swift` — `GAIIntegrationOrchestrator` 实现

**复用既有能力**：P1-P6 全部桥接（不修改）

**硬约束映射**：H1-H28

#### M11-P7-TASK-001.1: 实现 GAIIntegrationOrchestrator 依赖注入
- [ ] 定义 `GAIIntegrationOrchestrator` final class，`@unchecked Sendable`
- [ ] `init(gaiBridge: GAIRuntimeBridge, contextBridge: AgentContextBridge, toolBridge: AIToolInvocationBridge, authBridge: AICapabilityAuthorizationBridge, auditBridge: AIAuditBridge, codeArtsOrchestrator: CodeArtsAgentOrchestrator)`

#### M11-P7-TASK-001.2: 定义 GAIIntegrationResult 值类型
- [ ] 定义 `GAIIntegrationResult` struct（workflowState / toolCallResults / auditRecordIDs / status），`Sendable + Codable + Equatable`

#### M11-P7-TASK-001.3: 实现 runGAIIntegration
- [ ] 串联 G-AI → Agent → Tool → Contract → Auth → Exec → Audit 全链路
- [ ] 调用 `gaiBridge.submitTask` → `contextBridge.gatherContext` → `toolBridge.invoke` → `auditBridge.record`
- [ ] 返回 `GAIIntegrationResult`

#### M11-P7-TASK-001.4: 实现 runCodeArtsIntegration
- [ ] 串联 CodeArts Agent → Adapter → Contract → Auth → Exec → Audit 全链路
- [ ] 调用 `codeArtsOrchestrator.executeWorkflow`
- [ ] 返回 `CodeArtsAgentResult`

---

### M11-P7-TASK-002: G-AI 端到端集成测试

**任务描述**：编写 G-AI 端到端集成测试，验证 G-AI → Agent → Tool → Contract → Auth → Exec → Audit 全链路。

**输入**：TASK-001 实现

**输出**：G-AI 端到端测试文件

**依赖**：M11-P7-TASK-001

**验收标准**：
- G-AI 全链路集成测试 PASS
- 验证 H28 全链路

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/EndToEndGAIIntegrationTests.swift`

**硬约束映射**：H28-1 ~ H28-10

#### M11-P7-TASK-002.1: G-AI 全链路集成测试
- [ ] `testGAIFullChain_specToGate`：测试 G-AI SPEC → DESIGN → TASK → IMPLEMENTATION → TEST → EVIDENCE → REVIEW → GATE 全链路
- [ ] `testGAIInferencePath`：测试 G-AI 推理路径（经 M6 ModelProvider + AIBoundaryValidator）
- [ ] `testGAIWorkflowAdvance`：测试 G-AI 流程推进（经 M7 AgentRuntimeOrchestrator）
- [ ] `testGAIHighRiskApproval`：测试 G-AI 高危操作经 Approval Gate（H2 不可 bypass）

---

### M11-P7-TASK-003: CodeArts Agent 端到端集成测试

**任务描述**：编写 CodeArts Agent 端到端集成测试，验证 CodeArts Agent → Adapter → Contract → Auth → Exec → Audit 全链路。

**输入**：TASK-001 实现

**输出**：CodeArts Agent 端到端测试文件

**依赖**：M11-P7-TASK-001

**验收标准**：
- CodeArts Agent 全链路集成测试 PASS

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/EndToEndCodeArtsAgentTests.swift`

**硬约束映射**：H19-H28

#### M11-P7-TASK-003.1: CodeArts Agent 全链路集成测试
- [ ] `testCodeArtsAgentFullChain`：测试 CodeArts Agent → Adapter → Contract → Auth → Exec → Audit 全链路
- [ ] `testCodeArtsAgentContextViaPublicProtocolSurface`：测试 CodeArts Agent 上下文经 `PublicProtocolSurface`（H22）
- [ ] `testCodeArtsAgentCapabilityInvocation`：测试 Capability 调用经 H19 全链路

---

### M11-P7-TASK-004: H28 全链路验收测试

**任务描述**：编写 H28-1 ~ H28-10 全链路验收测试，验证 H28 AI Execution Boundary 全部 10 项验收条件。

**输入**：TASK-001 实现 + TASK-002 + TASK-003

**输出**：H28 全链路测试文件

**依赖**：M11-P7-TASK-003

**验收标准**：
- H28-1 ~ H28-10 全部验收测试 PASS

**涉及文件**（新增）：
- `Tests/AppKCodeApplicationTests/GAIBridge/H28FullChainTests.swift`

**硬约束映射**：H28-1 ~ H28-10

#### M11-P7-TASK-004.1: H28-1 ~ H28-6 验收测试（链路存在性）
- [ ] `testH28_1_fullChain_gaiInferenceViaModelProvider`：G-AI 推理经 M6 ModelProvider + AIBoundaryValidator
- [ ] `testH28_2_fullChain_aiToolCallViaToolRegistry`：AI 工具调用经 M7 ToolRegistry
- [ ] `testH28_3_fullChain_aiHighRiskViaAuthorizationGate`：AI 高危操作经 M7 AuthorizationGate 强制审批
- [ ] `testH28_4_fullChain_aiCapabilityViaEnforceContract`：AI Capability 调用经 M9 enforceContract
- [ ] `testH28_5_fullChain_aiExtensionViaExtensionAuthorizationIntegration`：AI Extension 调用经 M9 ExtensionAuthorizationIntegration
- [ ] `testH28_6_fullChain_allAIActionsViaAuditService`：所有 AI 动作经 M7 AuditService 审计

#### M11-P7-TASK-004.2: H28-7 ~ H28-9 验收测试（无 bypass 路径）
- [ ] `testH28_7_fullChain_noAIDirectShellExecution`：不存在 AI → Shell 直接执行路径
- [ ] `testH28_8_fullChain_noAIDirectGitExecution`：不存在 AI → Git 直接执行路径
- [ ] `testH28_9_fullChain_noAIDirectFileWrite`：不存在 AI → File 直接写入路径

#### M11-P7-TASK-004.3: H28-10 验收测试（单一审计系统）
- [ ] `testH28_10_fullChain_noSecondAuditSystem`：不存在第二套审计系统

#### M11-P7-TASK-004.4: 运行测试并验证回归
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P7 新增 tests PASS
- [ ] `arch-check.sh` → x86_64

---

### M11-P7-TASK-005: P7 Exit Gate 验证

**任务描述**：执行 P7 Exit Gate 全部验收检查。

**输入**：TASK-001 ~ TASK-004 全部完成

**输出**：P7 Exit Gate 通过证据

**依赖**：M11-P7-TASK-004

**验收标准**（Exit Gate）：
- [ ] `swift build` → 0 errors
- [ ] `swift test` → M0-M10 既有 1103 tests PASS + P1-P7 新增 tests PASS
- [ ] `arch-check.sh` → x86_64（H1）
- [ ] M10 `81bb91f` / M9 `23579c2` 源文件 0 modified
- [ ] H1-H28 全部验收 PASS（H28-1 ~ H28-10 全链路）
- [ ] PM Gate Review 通过，授权 P8

**硬约束映射**：H1-H28

---

## 10. M11-P8: Final Integration / Regression / Exit

**Phase 目标**：最终验收 + 全量回归 + 生成 `m11_exit_report.md`。

**Phase 前置**：P7 Exit Gate PASS + PM 授权 P8

**Phase 硬约束**：H1-H28 全部

**Phase 不修改**：M0-M10 任何源文件

### M11-P8-TASK-001: 全量回归测试

**任务描述**：执行全量回归测试，验证 M0-M10 既有 1103 tests + M11 新增 tests 全部 PASS。

**输入**：P1-P7 全部完成

**输出**：全量回归测试通过证据

**依赖**：M11-P7-TASK-005（P7 Exit Gate PASS）

**验收标准**：
- `swift build` → 0 errors
- `swift test` → M0-M10 既有 1103 tests + M11 新增 tests 全部 PASS
- `arch-check.sh` → x86_64

**涉及文件**：无新增（验证任务）

**硬约束映射**：H1

#### M11-P8-TASK-001.1: swift build 验证
- [ ] `swift build` → 0 errors
- [ ] 构建产物为 `x86_64-apple-macos13.0`

#### M11-P8-TASK-001.2: swift test 全量验证
- [ ] `swift test` → M0-M10 既有 1103 tests 全部 PASS
- [ ] `swift test` → M11 新增 tests 全部 PASS
- [ ] 统计 M11 新增 tests 总数

#### M11-P8-TASK-001.3: arch-check 验证
- [ ] `arch-check.sh` → `ARCH CHECK PASSED - All binaries are x86_64`
- [ ] `file .build/release/AppKCode` → `Mach-O 64-bit executable x86_64`

---

### M11-P8-TASK-002: Frozen 基线保护验证

**任务描述**：验证 M10 / M9 Frozen 基线源文件 0 modified。

**输入**：P1-P7 全部完成

**输出**：Frozen 基线保护通过证据

**依赖**：M11-P8-TASK-001

**验收标准**：
- M10 commit `81bb91f` 源文件 0 modified（`git diff` 校验）
- M9 commit `23579c2` 源文件 0 modified
- `AuditTarget` 枚举追加 case 为允许的例外（P5）

**涉及文件**：无新增（验证任务）

**硬约束映射**：H1-H27（基线保护）

#### M11-P8-TASK-002.1: M10 基线验证
- [ ] `git diff 81bb91f -- Sources/` → M0-M10 源文件 0 modified（仅 M11 新增文件）
- [ ] `git diff 81bb91f -- Tests/` → M0-M10 测试文件 0 modified（仅 M11 新增测试）
- [ ] 例外：`Sources/AppKCodeShared/AgentRuntime/AuditTypes.swift` 的 `AuditTarget` 枚举追加 case（P5 允许）

#### M11-P8-TASK-002.2: M9 基线验证
- [ ] `git diff 23579c2 -- Sources/` → M0-M9 源文件 0 modified
- [ ] `git diff 23579c2 -- Tests/` → M0-M9 测试文件 0 modified

#### M11-P8-TASK-002.3: M0-M8 基线验证
- [ ] 验证 M0-M8 Frozen Commit 均未修改（`66a78fc` / `eccb894` / `84e50a2` / `30fed8a` / `bca4fe3` / `c5024f1` / `27b0824` / `e19170b` / `c2a982a`）

---

### M11-P8-TASK-003: H1-H28 全部硬约束回归验证

**任务描述**：验证 H1-H28 全部硬约束 PASS。

**输入**：P1-P7 全部完成

**输出**：硬约束回归通过证据

**依赖**：M11-P8-TASK-002

**验收标准**：
- H1-H27 全部回归 PASS
- H28-1 ~ H28-10 全部验收 PASS

**涉及文件**：无新增（验证任务）

**硬约束映射**：H1-H28

#### M11-P8-TASK-003.1: H1-H27 既有硬约束回归
- [ ] H1 x86_64 Architecture Only → `arch-check.sh` PASS
- [ ] H2 No Bypass Path → M0 ApprovalGate 测试 PASS
- [ ] H3 Local Mode Default → M6 LocalModeResolver 测试 PASS
- [ ] H7 危险命令拦截 → M7 CommandExecuteTool 测试 PASS
- [ ] H9 AI Approval Boundary → M6 AIBoundaryValidator 测试 PASS
- [ ] H10 Context Isolation → M6 ContextAggregator 测试 PASS
- [ ] H11 Local Mode 端点 → M6 LocalModelClient 测试 PASS
- [ ] H12 Agent Authorization → M7 AuthorizationGate 测试 PASS
- [ ] H13 Tool Isolation → M7 AgentTool 测试 PASS
- [ ] H14 Agent Audit → M7 AuditService 测试 PASS
- [ ] H15 MCP Isolation → M8 MCPToolInvocation 测试 PASS
- [ ] H16 Skill Isolation → M8 SkillExecutionPolicy 测试 PASS
- [ ] H17 Rules 优先级 → M8 RuleEnforcer 测试 PASS
- [ ] H18 MCP/Skill Audit → M7 AuditService（AuditTarget.mcp/skill）测试 PASS
- [ ] H19 Compatibility Isolation → M9 全链路测试 PASS
- [ ] H20 Extension Authorization → M9 ExtensionAuthorizationIntegration 测试 PASS
- [ ] H21 Capability Contract → M9 CapabilityContractRegistry 测试 PASS
- [ ] H22 Adapter Isolation → M9 PublicProtocolSurface 测试 PASS
- [ ] H23 Compatibility Audit → M9 ExtensionAuditIntegration 测试 PASS
- [ ] H24 Version Negotiation → M9 VersionNegotiationService 测试 PASS
- [ ] H25 Process Isolation → M10 ExtensionHostProcessManager 测试 PASS
- [ ] H26 API Surface Boundary → M10 VSCodeAPISurfaceRegistry / JetBrainsOpenAPISurfaceRegistry 测试 PASS
- [ ] H27 Resource Limit → M10 ExtensionResourceLimiter 测试 PASS

#### M11-P8-TASK-003.2: H28-1 ~ H28-10 新增硬约束验收
- [ ] H28-1: G-AI 推理经 M6 ModelProvider + AIBoundaryValidator → P1/P7 测试 PASS
- [ ] H28-2: AI 工具调用经 M7 ToolRegistry → P3/P7 测试 PASS
- [ ] H28-3: AI 高危操作经 M7 AuthorizationGate 强制审批 → P4/P7 测试 PASS
- [ ] H28-4: AI Capability 调用经 M9 enforceContract → P4/P7 测试 PASS
- [ ] H28-5: AI Extension 调用经 M9 ExtensionAuthorizationIntegration → P4/P7 测试 PASS
- [ ] H28-6: 所有 AI 动作经 M7 AuditService 审计 → P5/P7 测试 PASS
- [ ] H28-7: 不存在 AI → Shell 直接执行路径 → P3/P7 测试 PASS
- [ ] H28-8: 不存在 AI → Git 直接执行路径 → P3/P7 测试 PASS
- [ ] H28-9: 不存在 AI → File 直接写入路径 → P3/P7 测试 PASS
- [ ] H28-10: 不存在第二套审计系统 → P5/P7 测试 PASS

---

### M11-P8-TASK-004: 生成 m11_exit_report.md

**任务描述**：生成 M11 Exit Report，记录 M11 最终状态、测试结果、硬约束验收、Frozen 基线保护。

**输入**：TASK-001 ~ TASK-003 全部完成

**输出**：`m11_exit_report.md` 文件

**依赖**：M11-P8-TASK-003

**验收标准**：
- Exit Report 包含 M11 最终状态
- 包含测试结果（M0-M10 既有 + M11 新增）
- 包含 H1-H28 全部硬约束验收
- 包含 Frozen 基线保护证据
- 包含 M11 不变性确认

**涉及文件**（新增）：
- `.codeartsdoer/specs/appk_spec_001/m11_exit_report.md` — M11 Exit Report

**硬约束映射**：H1-H28

#### M11-P8-TASK-004.1: 编写 M11 Exit Report
- [ ] 记录 M11 最终状态（PASS / CLOSED / FROZEN）
- [ ] 记录 M11 Final Commit
- [ ] 记录测试结果（M0-M10 既有 1103 tests + M11 新增 tests 总数）
- [ ] 记录 H1-H28 全部硬约束验收结果
- [ ] 记录 Frozen 基线保护证据（M10 `81bb91f` / M9 `23579c2` 0 modified）
- [ ] 记录 M11 不变性确认（H1/H2/H9/H10/H12/H14/H17/H20/H21/H22/H23/H25/H27 不变 + H28 新增）
- [ ] 记录 M11 Phase 完成总结（P0-P8）

---

### M11-P8-TASK-005: P8 Exit Gate + PM Gate Review

**任务描述**：执行 P8 Exit Gate 全部验收检查，请求 PM 最终 Gate Review。

**输入**：TASK-001 ~ TASK-004 全部完成

**输出**：P8 Exit Gate 通过证据 + PM Gate Review 结果

**依赖**：M11-P8-TASK-004

**验收标准**（Exit Gate）：
- [ ] `swift build` → 0 errors
- [ ] `swift test` → M0-M10 既有 1103 tests + M11 新增 tests 全部 PASS
- [ ] `arch-check.sh` → x86_64（H1）
- [ ] M10 `81bb91f` / M9 `23579c2` 源文件 0 modified
- [ ] H1-H28 全部验收 PASS
- [ ] `m11_exit_report.md` 生成
- [ ] PM Gate Review 通过，M11 CLOSED / FROZEN

**硬约束映射**：H1-H28

---

## 11. Exit Gate 定义汇总

### 11.1 通用 Exit Gate 标准

每个 Phase 的 Exit Gate 必须满足：
1. `swift build` → 0 errors
2. `swift test` → M0-M10 既有 1103 tests 全部 PASS + 本 Phase 新增 tests PASS
3. `arch-check.sh` → x86_64（H1）
4. M10 commit `81bb91f` 源文件 0 modified（`git diff` 校验，`AuditTarget` 追加 case 为允许例外）
5. M9 commit `23579c2` 源文件 0 modified
6. 本 Phase 硬约束验收 PASS
7. 本 Phase 不引入禁止项
8. PM Gate Review 通过，授权下一 Phase

### 11.2 各 Phase Exit Gate

| Phase | Exit Gate | 硬约束 | 产出 |
|-------|-----------|--------|------|
| P1 | `GAIRuntimeBridge` 协议 + 实现 + 测试 PASS | H3/H9/H11/H28-1 | 5 files |
| P2 | `AgentContextBridge` 协议 + 实现 + 测试 PASS | H10/H22/H28 | 4 files |
| P3 | `AIToolInvocationBridge` + H28-2/7/8/9 验收 PASS | H15/H16/H17/H28-2/H28-7/H28-8/H28-9 | 4 files |
| P4 | `AICapabilityAuthorizationBridge` + H28-3/4/5 验收 PASS | H2/H12/H20/H21/H28-3/H28-4/H28-5 | 3 files |
| P5 | `AIAuditBridge` + AuditTarget 扩展 + H28-6/10 验收 PASS | H14/H18/H23/H28-6/H28-10 | 3 files + 1 modified |
| P6 | `CodeArtsAgentOrchestrator` + H19-H27 验收 PASS | H19-H28 | 2 files |
| P7 | `GAIIntegrationOrchestrator` + 端到端 + H28 全链路 PASS | H1-H28 | 4 files |
| P8 | 全量回归 + Exit Report + PM Gate Review | H1-H28 | 1 file (`m11_exit_report.md`) |

### 11.3 M11 最终 Exit Gate（P8）

| 检查项 | 验收标准 |
|--------|---------|
| `swift build` | 0 errors |
| `swift test` | M0-M10 既有 1103 tests + M11 新增 tests 全部 PASS |
| `arch-check.sh` | x86_64（H1） |
| M10 `81bb91f` 基线 | 源文件 0 modified（`AuditTarget` 追加 case 例外） |
| M9 `23579c2` 基线 | 源文件 0 modified |
| H1-H27 既有硬约束 | 全部回归 PASS |
| H28-1 ~ H28-10 新增硬约束 | 全部验收 PASS |
| `m11_exit_report.md` | 生成并内容完整 |
| PM Gate Review | 通过，M11 CLOSED / FROZEN |

---

## 12. 硬约束映射矩阵

### 12.1 任务 → 硬约束映射

| 任务编号 | 硬约束 | 验收方式 |
|---------|--------|---------|
| M11-P1-TASK-001 | H28 | 类型定义为 H28 桥接基础 |
| M11-P1-TASK-002 | H28 | 协议为 H28 桥接入口 |
| M11-P1-TASK-003 | H3/H9/H11/H28-1 | 推理经 M6 ModelProvider + AIBoundaryValidator |
| M11-P1-TASK-004 | H28-1 | H28-1 验收测试 |
| M11-P1-TASK-005 | H1/H3/H9/H11/H28-1 | P1 Exit Gate |
| M11-P2-TASK-001 | H10/H22 | 协议定义 |
| M11-P2-TASK-002 | H10 | 经 M6 ContextAggregator |
| M11-P2-TASK-003 | H22 | 经 M9 PublicProtocolSurface |
| M11-P2-TASK-004 | H10/H22 | H10/H22 验收测试 |
| M11-P2-TASK-005 | H1/H10/H22/H28 | P2 Exit Gate |
| M11-P3-TASK-001 | H28-2 | 协议定义 |
| M11-P3-TASK-002 | H13/H15/H16/H17/H28-2/H28-3/H28-7/H28-8/H28-9 | 工具调用经 ToolRegistry + ActionExecutor |
| M11-P3-TASK-003 | H28-2/H28-7/H28-8/H28-9 | H28 验收测试 |
| M11-P3-TASK-004 | H1/H15/H16/H17/H28-2/H28-7/H28-8/H28-9 | P3 Exit Gate |
| M11-P4-TASK-001 | H28-4/H28-5 | 协议定义 |
| M11-P4-TASK-002 | H2/H12/H20/H21/H28-3/H28-4/H28-5 | 授权经 enforceContract + ExtensionAuth + AuthGate |
| M11-P4-TASK-003 | H2/H12/H20/H21/H28-3/H28-4/H28-5 | H28 验收测试 |
| M11-P4-TASK-004 | H1/H2/H12/H20/H21/H28-3/H28-4/H28-5 | P4 Exit Gate |
| M11-P5-TASK-001 | H14/H28-6 | 协议定义 |
| M11-P5-TASK-002 | H14/H23/H28-6/H28-10 | AuditTarget 扩展 |
| M11-P5-TASK-003 | H14/H23/H28-6/H28-10 | 经 M7 AuditService |
| M11-P5-TASK-004 | H14/H18/H23/H28-6/H28-10 | H28 验收测试 |
| M11-P5-TASK-005 | H1/H14/H18/H23/H28-6/H28-10 | P5 Exit Gate |
| M11-P6-TASK-001 | H19/H28 | 定义 |
| M11-P6-TASK-002 | H19/H20/H21/H22/H23/H24/H25/H26/H27/H28 | 经 M9 CapabilityAppService + M10 |
| M11-P6-TASK-003 | H19-H28 | H19-H27 验收测试 |
| M11-P6-TASK-004 | H1/H19-H28 | P6 Exit Gate |
| M11-P7-TASK-001 | H1-H28 | 端到端编排 |
| M11-P7-TASK-002 | H28-1~H28-10 | G-AI 端到端测试 |
| M11-P7-TASK-003 | H19-H28 | CodeArts 端到端测试 |
| M11-P7-TASK-004 | H28-1~H28-10 | H28 全链路验收 |
| M11-P7-TASK-005 | H1-H28 | P7 Exit Gate |
| M11-P8-TASK-001 | H1 | 全量回归 |
| M11-P8-TASK-002 | H1-H27 | Frozen 基线保护 |
| M11-P8-TASK-003 | H1-H28 | 硬约束回归 |
| M11-P8-TASK-004 | H1-H28 | Exit Report |
| M11-P8-TASK-005 | H1-H28 | P8 Exit Gate + PM Gate Review |

### 12.2 H28 验收条件 → Phase → Task 映射

| H28 验收条件 | Phase | 主验收 Task | 辅助验收 Task |
|-------------|-------|------------|-------------|
| H28-1: G-AI 推理经 M6 ModelProvider + AIBoundaryValidator | P1 | M11-P1-TASK-004 | M11-P7-TASK-004 |
| H28-2: AI 工具调用经 M7 ToolRegistry | P3 | M11-P3-TASK-003 | M11-P7-TASK-004 |
| H28-3: AI 高危操作经 M7 AuthorizationGate 强制审批 | P4 | M11-P4-TASK-003 | M11-P3-TASK-002 / M11-P7-TASK-004 |
| H28-4: AI Capability 调用经 M9 enforceContract | P4 | M11-P4-TASK-003 | M11-P7-TASK-004 |
| H28-5: AI Extension 调用经 M9 ExtensionAuthorizationIntegration | P4 | M11-P4-TASK-003 | M11-P7-TASK-004 |
| H28-6: 所有 AI 动作经 M7 AuditService 审计 | P5 | M11-P5-TASK-004 | M11-P7-TASK-004 |
| H28-7: 不存在 AI → Shell 直接执行路径 | P3 | M11-P3-TASK-003 | M11-P7-TASK-004 |
| H28-8: 不存在 AI → Git 直接执行路径 | P3 | M11-P3-TASK-003 | M11-P7-TASK-004 |
| H28-9: 不存在 AI → File 直接写入路径 | P3 | M11-P3-TASK-003 | M11-P7-TASK-004 |
| H28-10: 不存在第二套审计系统 | P5 | M11-P5-TASK-004 | M11-P7-TASK-004 |

---

## 13. M10 Frozen Baseline 保护

### 13.1 Frozen 基线状态

| 里程碑 | Commit | Tests | M11 保护规则 |
|--------|--------|-------|-------------|
| M0 | `66a78fc` | 30/30 | 0 modified |
| M1 | `eccb894` | 52/52 | 0 modified |
| M2 | `84e50a2` | 105/105 | 0 modified |
| M3 | `30fed8a` | 165/165 | 0 modified |
| M4 | `bca4fe3` | 278/278 | 0 modified |
| M5 | `c5024f1` | 392/392 | 0 modified |
| M6 | `27b0824` | 489/489 | 0 modified |
| M7 | `e19170b` | 545/545 | 0 modified |
| M8 | `c2a982a` | 586/586 | 0 modified |
| M9 | `23579c2` | 625/625 | 0 modified |
| M10 | `81bb91f` | 1103/1103 | 0 modified |

### 13.2 M11 基线保护规则

| 层 | M11 不修改的文件 | M11 可新增的文件 |
|----|-----------------|-----------------|
| Shared | M0-M10 所有 Shared 类型文件 | M11 新增 Shared 类型 |
| Infrastructure | M0-M10 所有 Infra 实现 | M11 新增 Infra 实现 |
| Domain | M0-M10 所有 Domain 实现 | M11 新增 Domain 实现（P1-P5 桥接协议） |
| Application | M0-M10 所有 App 编排 | M11 新增 App 编排（P1-P7 桥接实现） |
| Presentation | M0-M10 所有 UI | M11 新增 UI（如 `GAIRuntimePanelView`，本任务规划不含） |
| Tests | M0-M10 所有测试文件 | M11 新增测试文件 |

### 13.3 允许的例外（仅追加，不修改语义）

| 文件 | 修改内容 | Phase | 约束 |
|------|---------|-------|------|
| `Sources/AppKCodeShared/AgentRuntime/AuditTypes.swift` | `AuditTarget` enum 追加 `aiInference` / `gaiRuntime` / `aiToolCall` case | P5 | 不修改既有 case，不修改 `AgentAuditRecord` 8 字段结构 |

### 13.4 每阶段 Exit Gate 基线验证

- `git diff 81bb91f -- Sources/` → M0-M10 源文件 0 modified（仅 M11 新增文件 + `AuditTarget` 追加 case 例外）
- `git diff 23579c2 -- Sources/` → M0-M9 源文件 0 modified
- `swift test` → M0-M10 既有 1103 tests 全部 PASS

---

## 14. x86_64 约束

### 14.1 H1 约束保持不变

- M11 新增的所有 Swift 代码必须构建为 `x86_64-apple-macos13.0`
- M11 不引入 ARM64-only 依赖
- M11 不引入 ARM64 二进制强行加载到 x86_64
- M11 构建产物经 `arch-check.sh` 校验
- M11 不修改构建目标三元组（保持 `x86_64-apple-macos13.0`）
- M11 不修改 `arch-check.sh`
- M11 不修改 `Package.swift` 构建目标

### 14.2 每阶段 Exit Gate x86_64 验证

- `arch-check.sh` → `ARCH CHECK PASSED - All binaries are x86_64`
- `file .build/release/AppKCode` → `Mach-O 64-bit executable x86_64`

---

## 15. 明确禁止事项

### 15.1 M11 全局禁止事项

```
❌ 自主 Agent 无限循环（必须有 maxSteps 限制 + 用户可中断）
❌ 自动修改整个项目
❌ 自动执行 Shell（H28-7）
❌ 自动 Git Commit（H28-8）
❌ 自动 Git Push（H28-8）
❌ 自动部署
❌ 绕过用户 Approval（H2/H28-3）
❌ 私有 CodeArts API 逆向
❌ 宣称"所有 CodeArts 插件完全兼容"
❌ ARM64 二进制强行加载到 x86_64（H1）
❌ 修改 M0-M10 Frozen 基线
❌ reset / amend / force push 已有 Frozen Commit
❌ 创建第二套审计系统（H23/H28-10）
❌ 创建第二套授权系统（H12/H28）
❌ 自动授权任何 Phase 的执行（每 Phase 需 PM Gate Review 授权）
```

### 15.2 M11 技术禁止事项

| 编号 | 禁止事项 | 硬约束 | 实现保障 |
|------|---------|--------|---------|
| B1 | 禁止 AI 生成的动作绕过 AuthorizationGate | H28/H12/H2 | `AIToolInvocationBridgeImpl` 唯一入口经 `AuthorizationGate` |
| B2 | 禁止 AI 生成的动作绕过 enforceContract | H28/H21 | `AICapabilityAuthorizationBridgeImpl` 唯一入口经 `enforceContract` |
| B3 | 禁止 AI 生成的动作绕过 AuditService | H28/H14/H23 | `AIAuditBridgeImpl` 唯一入口经 `AuditService.record` |
| B4 | 禁止 AI 生成的动作绕过 Approval Gate（高危） | H28/H2 | M7 `AuthorizationGateImpl` high → `ApprovalService`（FROZEN） |
| B5 | 禁止 AI → Shell 直接执行 | H28/H7 | `AIToolInvocationBridgeImpl` 仅经 `ToolRegistry` + `ActionExecutor` |
| B6 | 禁止 AI → Git 直接执行 | H28/H8 | Git 操作仅经 M7 `GitTools`（`ToolRegistry` 注册） |
| B7 | 禁止 AI → File 直接写入 | H28/H12 | 文件写入仅经 M7 `FileWriteTool`（high → Approval） |
| B8 | 禁止第二套审计系统 | H23/H28 | M11 仅扩展 `AuditTarget` 枚举，不创建新 `AuditService` |
| B9 | 禁止第二套授权系统 | H12/H28 | M11 不创建新 `AuthorizationGate` 实现 |
| B10 | 禁止 G-AI Runtime 绕过 M6 ModelProvider | H28/H9/H11 | `GAIRuntimeBridgeImpl` 经 `ModelProviderRegistry` |
| B11 | 禁止 G-AI Runtime 绕过 M6 AIBoundaryValidator | H28/H9 | `GAIRuntimeBridgeImpl` 经 `AIBoundaryValidator.validate` |
| B12 | 禁止 G-AI Runtime 自主无限循环 | §15.1 | `GAIWorkflowTask.maxSteps` 限制 + 用户 `cancel` |
| B13 | 禁止 CodeArts Agent 拥有独立 Authorization | H20/H28 | CodeArts Agent 经 M9 `ExtensionAuthorizationIntegration` → M7 |
| B14 | 禁止 CodeArts Agent 拥有独立 Audit | H23/H28 | CodeArts Agent 经 M9 `ExtensionAuditIntegration` → M7 |
| B15 | 禁止 CodeArts Agent 直接访问宿主内部 | H22/H28 | CodeArts Agent 经 M9 `PublicProtocolSurface` |
| B16 | 禁止引入 ARM64-only 依赖 | H1 | 构建目标保持 `x86_64-apple-macos13.0` |
| B17 | 禁止修改构建目标三元组 | H1 | 不修改 `Package.swift` 构建目标 |
| B18 | 禁止修改 M0-M10 任何源文件语义 | §13 | 每阶段 `git diff` 校验 |
| B19 | 禁止修改 M0-M10 任何测试文件 | §13 | 每阶段 `git diff` 校验 |
| B20 | 禁止 reset / amend / force push Frozen Commit | §13 | Git 安全协议 |
| B21 | 禁止自动授权任何 Phase 执行 | §15.1 | 每 Phase 需 PM Gate Review 授权 |

### 15.3 M11 不宣称事项

- ❌ 不宣称"所有 CodeArts 插件完全兼容"
- ❌ 不宣称"所有 VS Code 插件完全兼容"
- ❌ 不宣称"所有 JetBrains 插件完全兼容"
- ❌ 不宣称"私有 CodeArts API 逆向兼容"
- ❌ 不宣称"G-AI Runtime 全流程自主完成"（必须经用户审批，H2/H28-3）
- ❌ 不宣称"AI Agent 可替代人类决策"（高危必须人工审批，H2）

---

## 16. M11 新增文件汇总

### 16.1 新增文件清单

| Phase | 文件路径 | 层 | 内容 |
|-------|---------|---|------|
| P1 | `Sources/AppKCodeDomain/GAIBridge/GAIWorkflowTypes.swift` | Domain | G-AI 流程值类型 |
| P1 | `Sources/AppKCodeDomain/GAIBridge/GAIRuntimeBridge.swift` | Domain | GAIRuntimeBridge protocol |
| P1 | `Sources/AppKCodeDomain/GAIBridge/AIAuditBridge.swift` | Domain | AIAuditBridge protocol（前置定义，P5 补充） |
| P1 | `Sources/AppKCodeApplication/GAIBridge/GAIRuntimeBridgeImpl.swift` | Application | GAIRuntimeBridgeImpl 实现 |
| P1 | `Tests/AppKCodeApplicationTests/GAIBridge/GAIRuntimeBridgeTests.swift` | Tests | P1 单元测试 |
| P1 | `Tests/AppKCodeApplicationTests/GAIBridge/GAIWorkflowStateMachineTests.swift` | Tests | 状态机测试 |
| P2 | `Sources/AppKCodeDomain/GAIBridge/AgentContextBridge.swift` | Domain | AgentContextBridge protocol |
| P2 | `Sources/AppKCodeApplication/GAIBridge/AgentContextBridgeImpl.swift` | Application | AgentContextBridgeImpl 实现 |
| P2 | `Sources/AppKCodeApplication/GAIBridge/CodeArtsAgentContextAdapter.swift` | Application | CodeArtsAgentContextAdapter 实现 |
| P2 | `Tests/AppKCodeApplicationTests/GAIBridge/AgentContextBridgeTests.swift` | Tests | P2 单元测试 |
| P3 | `Sources/AppKCodeDomain/GAIBridge/AIToolInvocationBridge.swift` | Domain | AIToolInvocationBridge protocol |
| P3 | `Sources/AppKCodeDomain/GAIBridge/AICapabilityAuthorizationBridge.swift` | Domain | AICapabilityAuthorizationBridge protocol（前置定义，P4 补充） |
| P3 | `Sources/AppKCodeApplication/GAIBridge/AIToolInvocationBridgeImpl.swift` | Application | AIToolInvocationBridgeImpl 实现 |
| P3 | `Tests/AppKCodeApplicationTests/GAIBridge/AIToolInvocationBridgeTests.swift` | Tests | P3 单元测试 |
| P3 | `Tests/AppKCodeApplicationTests/GAIBridge/AIToolInvocationH28Tests.swift` | Tests | H28-2/7/8/9 验收测试 |
| P4 | `Sources/AppKCodeApplication/GAIBridge/AICapabilityAuthorizationBridgeImpl.swift` | Application | AICapabilityAuthorizationBridgeImpl 实现 |
| P4 | `Tests/AppKCodeApplicationTests/GAIBridge/AICapabilityAuthorizationBridgeTests.swift` | Tests | P4 单元测试 + H28-3/4/5 验收 |
| P5 | `Sources/AppKCodeApplication/GAIBridge/AIAuditBridgeImpl.swift` | Application | AIAuditBridgeImpl 实现 |
| P5 | `Tests/AppKCodeApplicationTests/GAIBridge/AIAuditBridgeTests.swift` | Tests | P5 单元测试 + H28-6/10 验收 |
| P6 | `Sources/AppKCodeApplication/GAIBridge/CodeArtsAgentOrchestrator.swift` | Application | CodeArtsAgentOrchestrator + 值类型 |
| P6 | `Tests/AppKCodeApplicationTests/GAIBridge/CodeArtsAgentOrchestratorTests.swift` | Tests | P6 单元测试 + H19-H27 验收 |
| P7 | `Sources/AppKCodeApplication/GAIBridge/GAIIntegrationOrchestrator.swift` | Application | GAIIntegrationOrchestrator 端到端编排 |
| P7 | `Tests/AppKCodeApplicationTests/GAIBridge/EndToEndGAIIntegrationTests.swift` | Tests | G-AI 端到端测试 |
| P7 | `Tests/AppKCodeApplicationTests/GAIBridge/EndToEndCodeArtsAgentTests.swift` | Tests | CodeArts Agent 端到端测试 |
| P7 | `Tests/AppKCodeApplicationTests/GAIBridge/H28FullChainTests.swift` | Tests | H28 全链路验收测试 |
| P8 | `.codeartsdoer/specs/appk_spec_001/m11_exit_report.md` | Docs | M11 Exit Report |

### 16.2 修改文件清单（仅追加，不修改语义）

| Phase | 文件路径 | 修改内容 | 约束 |
|-------|---------|---------|------|
| P5 | `Sources/AppKCodeShared/AgentRuntime/AuditTypes.swift` | `AuditTarget` enum 追加 3 个 case | 不修改既有 case，不修改 `AgentAuditRecord` 8 字段结构 |

### 16.3 文件统计

| 类型 | 数量 |
|------|------|
| 新增 Domain 文件 | 5 |
| 新增 Application 文件 | 7 |
| 新增 Tests 文件 | 11 |
| 新增 Docs 文件 | 1 |
| 修改 Shared 文件（仅追加 case） | 1 |
| **总计** | **24 新增 + 1 修改** |

---

## 17. M11 不变性

M11 全程保持以下不变性：
1. **H1 不变**：x86_64-apple-macos13.0
2. **H2 不变**：Approval Gate 不可 bypass
3. **H9 不变**：AI Approval Boundary
4. **H10 不变**：Context Isolation
5. **H12 不变**：Agent Authorization 强制
6. **H14 不变**：Agent Audit 单一入口 + 8 字段 + SHA-256
7. **H17 不变**：Rules 约束对 AI 生成的 Plan 同样适用
8. **H20 不变**：Extension Authorization 默认拒绝
9. **H21 不变**：Capability Contract 强制
10. **H22 不变**：Adapter Isolation
11. **H23 不变**：无第二套审计系统
12. **H25 不变**：Process Isolation
13. **H27 不变**：Resource Limit
14. **M10 `81bb91f` 不变**：Frozen 基线保护
15. **M9 `23579c2` 不变**：Frozen 基线保护
16. **H28 新增**：AI Execution Boundary 强制（H28-1 ~ H28-10）

---

## 18. 授权 P1 的条件

### 18.1 授权 P1 的前置条件

| 编号 | 前置条件 | 状态 | 证据 |
|------|---------|------|------|
| C1 | M0-M10 全部 PASS / CLOSED / FROZEN | ✅ | M10 exit report: 1103/1103 tests PASS |
| C2 | M10 FROZEN commit `81bb91f` 基线稳定 | ✅ | M10 exit report: Working Tree Clean |
| C3 | M9 FROZEN commit `23579c2` 基线稳定 | ✅ | M10 exit report: M9 23579c2 Frozen ✅ Unmodified |
| C4 | H1-H27 全部 PASS | ✅ | M10 exit report: H1/H19-H27 全部 PASS |
| C5 | x86_64 架构锁定 | ✅ | M10 exit report: arch-check → x86_64 |
| C6 | P0 Scope Review 完成 | ✅ | `m11_scope_review.md` |
| C7 | M11 Design 完成 | ✅ | `m11_design.md` |
| C8 | M11 Task Plan 完成 | ✅ | 本文档 |
| C9 | H28 AI Execution Boundary 定义 | ✅ | Scope Review §9 |
| C10 | M11 Phase 划分明确 | ✅ | Scope Review §12 |
| C11 | 每阶段 Exit Gate 明确 | ✅ | Scope Review §13 + 本文档 §11 |
| C12 | 明确禁止事项列出 | ✅ | Scope Review §15 + 本文档 §15 |
| C13 | 本文档不修改 M0-M10 任何源文件 | ✅ | 本文档仅任务规划 |
| C14 | 本文档不创建任何 Swift 代码 | ✅ | 本文档仅任务规划 |
| C15 | PM 审核本文档通过 | ⏳ | **待 PM 审核** |

### 18.2 授权 P1 的条件判定

> **技术条件**：✅ 全部满足（C1-C14）
> **PM 审核**：⏳ 待 PM 审核本文档
> **授权 P1**：当且仅当 PM 审核本文档通过（C15 ✅）后，授权 M11-P1 启动

### 18.3 每阶段授权流程

```
P0 Scope Review ✅ → PM 审核 → 授权 P1
P1 Exit Gate PASS → PM Gate Review → 授权 P2
P2 Exit Gate PASS → PM Gate Review → 授权 P3
P3 Exit Gate PASS → PM Gate Review → 授权 P4
P4 Exit Gate PASS → PM Gate Review → 授权 P5
P5 Exit Gate PASS → PM Gate Review → 授权 P6
P6 Exit Gate PASS → PM Gate Review → 授权 P7
P7 Exit Gate PASS → PM Gate Review → 授权 P8
P8 Exit Gate PASS → PM Final Gate Review → M11 CLOSED / FROZEN
```

---

## 19. 任务统计汇总

### 19.1 任务数量统计

| Phase | 主任务数 | 子任务数 | 合计 |
|-------|---------|---------|------|
| P1 | 5 | 16 | 21 |
| P2 | 5 | 12 | 17 |
| P3 | 4 | 15 | 19 |
| P4 | 4 | 12 | 16 |
| P5 | 5 | 15 | 20 |
| P6 | 4 | 13 | 17 |
| P7 | 5 | 13 | 18 |
| P8 | 5 | 14 | 19 |
| **总计** | **37** | **110** | **147** |

### 19.2 硬约束覆盖统计

| 硬约束 | 覆盖 Phase | 覆盖 Task |
|--------|-----------|----------|
| H1 | P1-P8 | 所有 Exit Gate |
| H2 | P4 | M11-P4-TASK-002/003 |
| H3 | P1 | M11-P1-TASK-003 |
| H9 | P1 | M11-P1-TASK-003/004 |
| H10 | P2 | M11-P2-TASK-002/004 |
| H11 | P1 | M11-P1-TASK-003 |
| H12 | P3/P4 | M11-P3-TASK-002 / M11-P4-TASK-002/003 |
| H13 | P3 | M11-P3-TASK-002 |
| H14 | P5 | M11-P5-TASK-003/004 |
| H15 | P3 | M11-P3-TASK-002 |
| H16 | P3 | M11-P3-TASK-002 |
| H17 | P3 | M11-P3-TASK-002 |
| H18 | P5 | M11-P5-TASK-004 |
| H19 | P6 | M11-P6-TASK-002/003 |
| H20 | P4/P6 | M11-P4-TASK-002/003 / M11-P6-TASK-003 |
| H21 | P4/P6 | M11-P4-TASK-002/003 / M11-P6-TASK-003 |
| H22 | P2/P6 | M11-P2-TASK-003/004 / M11-P6-TASK-003 |
| H23 | P5/P6 | M11-P5-TASK-003/004 / M11-P6-TASK-003 |
| H24 | P6 | M11-P6-TASK-002/003 |
| H25 | P6 | M11-P6-TASK-002/003 |
| H26 | P6 | M11-P6-TASK-003 |
| H27 | P6 | M11-P6-TASK-002/003 |
| H28-1 | P1/P7 | M11-P1-TASK-004 / M11-P7-TASK-004 |
| H28-2 | P3/P7 | M11-P3-TASK-003 / M11-P7-TASK-004 |
| H28-3 | P3/P4/P7 | M11-P3-TASK-002 / M11-P4-TASK-003 / M11-P7-TASK-004 |
| H28-4 | P4/P7 | M11-P4-TASK-003 / M11-P7-TASK-004 |
| H28-5 | P4/P7 | M11-P4-TASK-003 / M11-P7-TASK-004 |
| H28-6 | P5/P7 | M11-P5-TASK-004 / M11-P7-TASK-004 |
| H28-7 | P3/P7 | M11-P3-TASK-003 / M11-P7-TASK-004 |
| H28-8 | P3/P7 | M11-P3-TASK-003 / M11-P7-TASK-004 |
| H28-9 | P3/P7 | M11-P3-TASK-003 / M11-P7-TASK-004 |
| H28-10 | P5/P7 | M11-P5-TASK-004 / M11-P7-TASK-004 |

---

## 20. 结论

### 20.1 Task Plan 完成状态

| 检查项 | 状态 |
|--------|------|
| 任务编号规范明确 | ✅（§1） |
| Phase 间依赖关系明确 | ✅（§2） |
| P1-P8 每个 Phase 任务列表 | ✅（§3-§10） |
| 每个 Task 输入/输出/依赖/验收标准 | ✅（各 Task 详述） |
| 子任务拆分 | ✅（各 Task 子任务） |
| Exit Gate 定义 | ✅（§11） |
| 硬约束映射矩阵 | ✅（§12） |
| M10 Frozen Baseline 保护 | ✅（§13） |
| x86_64 约束 | ✅（§14） |
| 明确禁止事项 | ✅（§15） |
| 新增文件汇总 | ✅（§16） |
| M11 不变性 | ✅（§17） |
| 授权 P1 的条件 | ✅（§18） |
| 不修改 M0-M10 任何源文件 | ✅（仅 `AuditTarget` 枚举追加 case） |
| 不创建任何 Swift 代码 | ✅（本文档仅任务规划） |
| 不自动授权任何 Phase | ✅（每 Phase 需 PM Gate Review） |

### 20.2 核心原则确认

```
G-AI → Agent → Tool/Capability → Contract → Authorization → Execution → Audit
```

**而非**：`G-AI → Shell → 随意执行`

✅ 本任务规划确保所有 AI 生成动作经统一链路，H28 AI Execution Boundary 强制不可绕过。

### 20.3 授权 P1 的条件

> **技术条件**：✅ 全部满足（C1-C14）
> **PM Gate Review**：⏳ 待 PM 审核本任务规划文档
> **授权 P1**：当且仅当 PM 审核本任务规划文档通过（C15 ✅）后，授权 M11-P1 启动

---

> **M11 Task Plan 完成**。本文档定义了 G-AI / CodeArts Agent 集成层的完整编码任务规划，包括 P1-P8 每个 Phase 的主任务与子任务、Exit Gate 定义、硬约束映射矩阵、M10 Frozen Baseline 保护规则、x86_64 约束和明确禁止事项。请求 PM 审核本任务规划文档，裁定是否授权 M11-P1 启动。
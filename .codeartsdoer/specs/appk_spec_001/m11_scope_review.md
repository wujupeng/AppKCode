# APPK-M11-P0 — G-AI / CodeArts Integration Scope Review

> **文档编号**: APPK-M11-SCOPE-001
> **版本**: v1.0
> **状态**: Scope Review (P0)
> **对应需求**: APPK-SPEC-001 v0.1 §5.3 (AI Agent) / §5.6 (MCP) / §5.7 (Skills/Rules) / §5.14 (G-AI Bridge)
> **对应设计**: APPK-DESIGN-001 v0.1 模块 B (AI Agent) / 模块 L (G-AI Bridge / Model Router)
> **里程碑**: M11 — G-AI / CodeArts Agent Integration
> **前置基线**: M10 commit `81bb91f`（1103/1103 tests PASS），M9 FROZEN `23579c2`（625/625 tests）
> **构建环境**: macOS 13.0, Swift 5.8, x86_64-apple-macos13.0
> **日期**: 2026-10-03
> **文档性质**: Scope Review（非编码任务，不产生 Swift 代码，不修改 M0-M10 任何源文件或测试文件）

---

## 0. 文档目的与范围

本文档是 M11 里程碑的 **P0 Integration Scope Review**，目的是在授权任何编码工作（P1+）之前，明确回答 8 个核心问题（P0-01 ~ P0-08），定义新增硬约束 **H28 AI Execution Boundary**，并形成可授权 P1 的条件判定。

**本文档不**：
- ❌ 不修改 M0-M10 任何源文件或测试文件
- ❌ 不创建任何 Swift 代码
- ❌ 不修改 M10 FROZEN 基线（commit `81bb91f`）
- ❌ 不修改 M9 FROZEN 基线（commit `23579c2`）
- ❌ 不 reset / amend 已有 Frozen Commit
- ❌ 不进行任何编码、设计细化或任务分解（属 P1+ 范畴）

**本文档产出**：仅 `m11_scope_review.md` 一份文档。

---

## 1. M11 目标

### 1.1 里程碑定位

M11 是 AppKCode 项目在 M0-M10 全部里程碑 PASS / CLOSED / FROZEN 之后的**集成层里程碑**。M0-M10 建立了分层能力（IDE Shell / Editor / LSP / Search / Build-Test / Git / AI Chat / Context / Agent Runtime / Authorization / Audit / MCP / Skills / Rules / Compatibility Foundation / VS Code-JetBrains Compatibility Layer），但各层尚未形成 **G-AI / CodeArts Agent 工作流集成**。

M11 的核心使命：**把 M7-M10 已经建立的能力真正串起来，形成 G-AI / CodeArts Agent 工作流集成层**，确保任何 AI 生成的动作都经过统一的能力解析、契约校验、授权、审批、执行、审计链路。

### 1.2 集成架构

```
                    AppKCode M11
                         │
             ┌───────────┴───────────┐
             │                       │
        CodeArts Agent          G-AI Runtime
             │                       │
             └───────────┬───────────┘
                         ↓
                  Agent Orchestrator
                         ↓
              MCP / Skills / Rules
                         ↓
                 Capability Contract
                         ↓
                    Authorization
                         ↓
                    Execution
                         ↓
                       Audit
```

### 1.3 核心原则

```
G-AI → Agent → Tool/Capability → Contract → Authorization → Execution → Audit
```

**而不是**：`G-AI → Shell → 随意执行`

### 1.4 M11 与既有里程碑的关系

| 里程碑 | 提供的能力 | M11 复用方式 |
|--------|-----------|-------------|
| M0 | Approval Gate 基础 | H2 不可 bypass，M11 不修改 |
| M3 | LSP / Search | Agent 上下文来源（Diagnostics） |
| M4 | Build / Test / ProcessRunner | Agent 工具（BuildTestTools） |
| M5 | Git Service | Agent 工具（GitTools） |
| M6 | AI Chat / Context / Model Provider | G-AI 推理接口 + 上下文桥接 |
| M7 | Agent Runtime / Authorization / Audit | Agent Loop + H12/H13/H14 |
| M8 | MCP / Skills / Rules | Agent 工具扩展 + H15/H16/H17/H18 |
| M9 | Compatibility Foundation | CodeArts Agent 接入 + H19-H24 |
| M10 | VS Code / JetBrains Compatibility | Extension Host 真实运行 + H25/H26/H27 |

### 1.5 M11 不重复实现

M11 是**集成层**，不重新实现任何既有能力：
- 不重新实现 Model Provider（复用 M6）
- 不重新实现 Agent Runtime / Authorization / Audit（复用 M7）
- 不重新实现 MCP / Skills / Rules（复用 M8）
- 不重新实现 Compatibility / Adapter / Contract（复用 M9）
- 不重新实现 Extension Host / Process Isolation / Resource Limit（复用 M10）

M11 新增的是**桥接层**：G-AI Runtime ↔ Agent Loop、CodeArts Agent ↔ Agent Loop、AI 工具调用 → 既有授权/审计链路的接入点。

---

## 2. G-AI Integration Boundary

### 2.1 G-AI Runtime 定义（来自 spec.md 领域术语）

> **G-AI Runtime**：用户自有的工程 Agent 运行时，遵循 SPEC→DESIGN→TASK→IMPLEMENTATION→TEST→EVIDENCE→REVIEW→GATE 流程。AppKCode 作为 G-AI 的 IDE 前端。

### 2.2 G-AI 集成边界声明

| 维度 | M11 集成范围 | M11 不集成 |
|------|-------------|-----------|
| 推理接口 | OpenAI-compatible Chat Completions API（M6 已实现） | 私有模型协议逆向 |
| 流程驱动 | SPEC→DESIGN→TASK→...→GATE 状态机桥接（M11-P1 定义） | 替代 G-AI Runtime 内部状态机 |
| 工具调用 | 经 M7 ToolRegistry / M9 CapabilityAppService（H28） | G-AI 直接 Shell 执行 |
| 上下文 | 经 M6 ContextAggregator（H10） | G-AI 直接读取文件系统 |
| 授权 | 经 M7 AuthorizationGate（H12）+ M6 AIBoundaryValidator（H9） | G-AI 自行授权 |
| 审计 | 经 M7 AuditService（H14） | 第二套审计系统 |
| Patch 提案 | 经 M7 FileWriteTool + Diff Review + Approval Gate | G-AI 直接写文件 |
| Git 操作 | 经 M7 GitTools + Approval Gate（高危） | G-AI 直接 git push |
| Local Mode | 经 M6 LocalModeResolver（H11），默认 127.0.0.1:8080 | G-AI 自行配置端点 |

### 2.3 G-AI 集成的两条路径

**路径 A：推理路径（M6 已实现）**
```
G-AI 推理请求
    ↓
M6 ModelProviderRegistry.resolve(provider)
    ↓
M6 OpenAICompatProvider / LocalModelProvider
    ↓
M6 ChatHTTPClient（SSE 流式 + 重试 + 超时）
    ↓
M6 AIBoundaryValidator（H9）
    ↓
推理结果
```

**路径 B：流程驱动路径（M11-P1 定义）**
```
G-AI 流程任务（SPEC→DESIGN→...→GATE）
    ↓
M11 GAIRuntimeBridge（新协议，P1 定义）
    ↓
M7 AgentRuntimeOrchestrator（复用）
    ↓
M7 Planner → ActionPlan
    ↓
M8 RuleEnforcer（应用 Rules 约束）
    ↓
M7 ActionExecutor → ToolRegistry
    ↓
M7 AuthorizationGate（H12）→ M7 AuditService（H14）
    ↓
流程状态推进
```

### 2.4 G-AI 集成禁止项

- ❌ 禁止 G-AI Runtime 绕过 M6 ModelProvider 直接发起 HTTP 请求
- ❌ 禁止 G-AI Runtime 绕过 M7 AuthorizationGate 直接执行副作用
- ❌ 禁止 G-AI Runtime 绕过 M7 AuditService（不创建第二套审计）
- ❌ 禁止 G-AI Runtime 自主无限循环（必须有终止条件 + 用户可中断）
- ❌ 禁止 G-AI Runtime 自动 Git Commit / Push / 部署
- ❌ 禁止 G-AI Runtime 在 Local Mode 下将代码外发（H11/H3）

---

## 3. CodeArts Agent Boundary

### 3.1 CodeArts Agent 定义

CodeArts Agent 指通过 AppKCode 兼容层接入的外部 Agent 插件，包括：
- CodeArts Agent Plugin（经 M9 `CodeArtsAdapter`）
- VS Code Extension（经 M10 `VSCodeExtensionHostAdapter`）
- JetBrains Plugin（经 M10 `JetBrainsPluginHostAdapter`）

### 3.2 CodeArts Agent 与 AppKCode Agent 的职责边界

| 维度 | AppKCode Agent（M7） | CodeArts Agent（M9/M10） |
|------|---------------------|--------------------------|
| **驱动方** | AppKCode 内部 `AgentRuntimeOrchestrator` | 外部 Plugin（经 `RuntimeAdapter` 协议） |
| **工具集** | `ToolRegistry`（`AgentTool` 协议，M7） | `CapabilityContractRegistry`（`CapabilityContract`，M9） |
| **授权** | `AuthorizationGateImpl`（H12） | `ExtensionAuthorizationIntegration`（H20）→ **同一 M7 AuthorizationGate** |
| **审计** | `AuditService`（H14） | `ExtensionAuditIntegration` → **同一 M7 AuditService**（H23） |
| **执行** | `ActionExecutor` → `AgentTool` | `CapabilityAppService.invokeCapability` → `RuntimeAdapter.invokeCapability` |
| **上下文** | `ContextAggregator`（M6，8 个 Provider） | 经 `PublicProtocolSurface` 注入（H22，不直接访问宿主内部） |
| **隔离** | Agent 沙箱（M7 `AgentSandboxManager`） | 进程隔离（M10 `ExtensionHostProcessManager`，H25） |
| **资源限制** | Agent 会话超时/取消 | `ResourceLimitStatus`（H27，内存/CPU/崩溃限制） |

### 3.3 关键原则

1. **CodeArts Agent 不拥有独立 Authorization**：必须经 M9 `ExtensionAuthorizationIntegration`（H20）→ M7 `AuthorizationGate`（H12）
2. **CodeArts Agent 不拥有独立 Audit**：必须经 M9 `ExtensionAuditIntegration`（H23）→ M7 `AuditService`（H14），无第二套审计
3. **CodeArts Agent 不直接访问宿主内部**：必须经 M9 `PublicProtocolSurface`（H22）+ `RuntimeAdapter` 协议
4. **CodeArts Agent 经 Contract 前置**：必须经 M9 `CapabilityContractRegistry.enforceContract`（H21），无 Contract 不执行
5. **CodeArts Agent 经版本协商**：必须经 M9 `VersionNegotiationService`（H24），不兼容拒绝加载

### 3.4 CodeArts Adapter 当前状态（M9/M10）

| Adapter | M9 状态 | M10 状态 | M11 是否深化 |
|---------|---------|----------|-------------|
| `CodeArtsAdapter` | Foundation（`invokeCapability → degraded`） | 保持 Foundation | **M11-P6 评估**，不强制深化 |
| `VSCodeExtensionHostAdapter` | Skeleton | 真实实现（IPC 到 Node.js Host） | M11 复用 M10 |
| `JetBrainsPluginHostAdapter` | Skeleton | 真实实现（RPC 到 JVM Host） | M11 复用 M10 |
| `CustomAdapter` | Abstraction | Abstraction | 按需 |

**M11 边界声明**：
- M11 不宣称"所有 CodeArts 插件完全兼容"
- M11 不进行私有 CodeArts API 逆向
- M11 复用 M10 VS Code / JetBrains 真实 Adapter，不重新实现
- CodeArts Adapter 是否在 M11 深化由 P6 阶段评估决定，非 P0 强制

---

## 4. Provider/API Contract

### 4.1 P0-01 回答：G-AI Runtime 的实际接口是什么

**G-AI Runtime 有两类接口**：

#### 4.1.1 推理接口（M6 已实现）

| 接口 | 协议 | 实现文件 | 状态 |
|------|------|---------|------|
| `ModelProvider` | Swift protocol（不绑定厂商） | `Sources/AppKCodeDomain/AIChat/ModelProvider.swift` | ✅ M6 |
| `ModelProviderRegistry` | 多 Provider 共存 | `Sources/AppKCodeDomain/AIChat/ModelProviderRegistry.swift` | ✅ M6 |
| `OpenAICompatProvider` | OpenAI-compatible Chat Completions | `Sources/AppKCodeDomain/AIChat/OpenAICompatProvider.swift` | ✅ M6 |
| `LocalModelProvider` | 本地端点（H11 默认 127.0.0.1:8080） | `Sources/AppKCodeDomain/AIChat/LocalModelProvider.swift` | ✅ M6 |
| `ChatHTTPClient` | SSE 流式 + 指数退避重试 3 次 + 超时 | `Sources/AppKCodeInfrastructure/AIChat/ChatHTTPClient.swift` | ✅ M6 |
| `LocalModelClient` | 本地端点校验（拒绝非 127.0.0.1 在 Local Mode） | `Sources/AppKCodeInfrastructure/AIChat/LocalModelClient.swift` | ✅ M6 |
| `LocalModeResolver` | H11 默认解析 | `Sources/AppKCodeDomain/AIChat/LocalModeResolver.swift` | ✅ M6 |
| `DomainModelRouter` | 按任务类型路由 | design.md §2.2.2.4 | ✅ M6 |

**推理接口契约**（OpenAI-compatible）：
- 端点：`POST /v1/chat/completions`
- 请求：`{model, messages, stream, temperature, ...}`
- 响应：SSE 流式（`data: {...}\n\n`）或一次性 JSON
- 鉴权：`Authorization: Bearer <key>`（本地端点可省略）
- 默认端点：`http://127.0.0.1:8080`（H3/H11）

#### 4.1.2 流程驱动接口（M11-P1 定义，M0 design.md 标注 TODO）

design.md 模块 L4 标注：
```
L4 G-AI Runtime 流程驱动 | G-AI 任务 | 流程状态 | SPEC→DESIGN→...→GATE 状态机 | B1、E1
```

M0 design.md §3 排除范围标注：
```
| G-AI Runtime 全流程桥接 | `AppKCodeDomain` 内 `GAIBridgeService` 桩 | `// TODO(M1): G-AI runtime bridge` |
```

**结论**：G-AI Runtime 的**推理接口**已由 M6 完整实现（OpenAI-compatible），但**流程驱动接口**（SPEC→DESIGN→TASK→IMPLEMENTATION→TEST→EVIDENCE→REVIEW→GATE 状态机桥接）尚未实现。M11-P1 需定义此接口，且必须：
- 经 M6 `ModelProvider` / `ModelProviderRegistry`（推理）
- 经 M6 `AIBoundaryValidator`（H9 AI Approval Boundary）
- 经 M7 `AgentRuntimeOrchestrator`（Agent Loop）
- 经 M7 `AuthorizationGate`（H12）+ `AuditService`（H14）

### 4.2 P0-02 回答：Local Model / OpenAI-compatible API 如何接入

**已由 M6 完整实现，M11 复用，不重新实现**。

**接入路径**：

| 场景 | 路径 |
|------|------|
| Local Model（默认） | 用户配置 `http://127.0.0.1:8080` → `LocalModelProvider` → `LocalModelClient` → `ChatHTTPClient` |
| OpenAI-compatible 云端 | 用户配置云端端点 + API Key → `OpenAICompatProvider` → `ChatHTTPClient` |
| 多模型路由 | `DomainModelRouter.route(taskType)` → `ModelEndpoint` → 对应 Provider |
| 设置 UI | `ModelProviderSettingsView`（M6 Presentation 层） |

**M11 边界**：
- M11 不修改 M6 Model Provider 任何源文件
- M11 新增的 G-AI Agent Loop 调用 Model Provider 时，必须经 `ModelProviderRegistry` + `AIBoundaryValidator`（H9）
- M11 不引入新的推理协议（仅复用 OpenAI-compatible）

### 4.3 Provider/API Contract 汇总

| Contract | 提供方 | 消费方 | M11 角色 |
|----------|--------|--------|---------|
| OpenAI-compatible Chat Completions | M6 `ModelProvider` | G-AI Runtime / AppKCode Agent | 复用，不修改 |
| SSE 流式响应 | M6 `ChatHTTPClient` | G-AI Runtime / Chat Panel | 复用，不修改 |
| Local Mode 默认端点 | M6 `LocalModeResolver`（H11） | 所有推理请求 | 复用，不修改 |
| AI Boundary 校验 | M6 `AIBoundaryValidator`（H9） | 所有推理请求 | 复用，不修改 |
| G-AI 流程驱动 | **M11-P1 定义** | G-AI Runtime | **M11 新增** |
| Model Router 路由 | M6 `DomainModelRouter` | Agent Loop | 复用，不修改 |

---

## 5. Agent Context Contract

### 5.1 P0-05 回答：Agent 如何读取 Workspace / Editor / Diagnostics

**已由 M6 完整实现（ContextAggregator + 8 个 ContextProvider），M11 复用**。

#### 5.1.1 既有 Context Provider（M6）

| Provider | 上下文来源 | 实现文件 | 依赖里程碑 |
|----------|-----------|---------|-----------|
| `CurrentFileContextProvider` | 当前编辑文件 | `Sources/AppKCodeDomain/Context/Providers/` | M0/M2 |
| `SelectedTextContextProvider` | 选中文本 | `Sources/AppKCodeDomain/Context/Providers/` | M2 |
| `CurrentSymbolContextProvider` | 当前符号 | `Sources/AppKCodeDomain/Context/Providers/` | M3 LSP |
| `OpenTabsContextProvider` | 打开的标签页 | `Sources/AppKCodeDomain/Context/Providers/` | M2 |
| `WorkspaceContextProvider` | 工作区 | `Sources/AppKCodeDomain/Context/Providers/` | M0 |
| `DiagnosticsContextProvider` | 诊断信息 | `Sources/AppKCodeDomain/Context/Providers/` | M3 LSP |
| `GitDiffContextProvider` | Git diff | `Sources/AppKCodeDomain/Context/Providers/` | M5 Git |
| `BuildTestResultsContextProvider` | 构建/测试结果 | `Sources/AppKCodeDomain/Context/Providers/` | M4 Build/Test |

#### 5.1.2 接入路径

**AppKCode Agent**（M7 已确认）：
```
AgentRuntimeOrchestrator
    ↓
M6 ContextAggregator.aggregate(providers, budget)
    ↓
ContextItem[]（每个含 source 标注，H10）
    ↓
ContextItemSerializer（截断 + 来源标注）
    ↓
推理请求上下文
```

**CodeArts Agent**（M9/M10）：
```
CodeArts Agent Plugin
    ↓
M9 PublicProtocolSurface（H22，受限 API 面）
    ↓
M9 RuntimeAdapter.invokeCapability
    ↓
AppKCode 原生服务（经 Contract + Auth + Audit）
```

#### 5.1.3 H10 Context Isolation 保障

- 每个 `ContextItem` 必须有 `source` 标注（H10）
- `ContextBudget` 截断（防止上下文爆炸）
- `ContextPreviewView` 显示来源（用户可审计上下文来源）
- CodeArts Agent 不直接访问宿主内部，经 `PublicProtocolSurface` 注入（H22）

### 5.2 M11 Agent Context Bridge

**M11 新增**：G-AI / CodeArts Agent 请求上下文的 Bridge 接口（P2 阶段定义），必须：
- 经 M6 `ContextAggregator`（H10）
- 不绕过 Context Budget 截断
- 不绕过 source 标注
- CodeArts Agent 经 `PublicProtocolSurface`（H22），不直接访问

**M11 不**：
- 不重新实现 Context Provider
- 不修改 M6 ContextAggregator
- 不允许 Agent 直接读取文件系统（必须经 ContextAggregator 或 M7 FileReadTool）

---

## 6. MCP/Skills/Rules 接入关系

### 6.1 P0-04 回答：MCP / Skills / Rules 如何进入 Agent Loop

**已由 M8 完整实现，M11 复用**。

#### 6.1.1 MCP 接入（M8，H15）

```
MCP Server（外部进程）
    ↓
M8 MCPHostService + MCPServerProcessManager
    ↓
M8 MCPToolDiscovery（工具发现）
    ↓
M8 MCPToolAdapter（适配 M7 AgentTool 协议）
    ↓
M7 ToolRegistry.register(MCPToolAdapter)
    ↓
M7 ActionExecutor → MCPToolInvocation → Transport（stdio/HTTP）
    ↓
M7 AuthorizationGate（H12，permission .high）→ M7 AuditService（H14，AuditTarget.mcp）
```

**隔离**（H15）：`MCPToolInvocation` → Transport，不直接访问 Process

#### 6.1.2 Skills 接入（M8，H16）

```
Skills 定义文件
    ↓
M8 SkillLoader → SkillRegistry
    ↓
M8 SkillExecutor → M7 ActionExecutor（含 Authorization + Audit）
    ↓
M8 SkillExecutionPolicy（requireApproval, maxSteps, allowedCategories）
    ↓
M7 AuthorizationGate（H12）→ M7 AuditService（H14，AuditTarget.skill）
```

**隔离**（H16）：`SkillExecutionPolicy.requireApproval = true` by default

#### 6.1.3 Rules 接入（M8，H17）

```
Rules 文件（coding.md / testing.md / security.md / PM-Gate.md）
    ↓
M8 RuleLoader → RuleEngine
    ↓
M8 RuleResolver（冲突解析）
    ↓
M8 RuleEnforcer（block / warn / info）
    ↓
M7 AgentRuntimeOrchestrator（接入 RuleEnforcer，在 Plan 生成后应用约束）
    ↓
M7 AuditService（H14，AuditTarget.rule）
```

**优先级**（H17）：`session > project > global`

#### 6.1.4 接入关系图

```
Agent Loop（M7 AgentRuntimeOrchestrator）
    ├── Planner → ActionPlan
    ├── RuleEnforcer（M8，应用 Rules 约束）
    ├── ActionExecutor
    │   ├── FileReadTool（M7，readOnly）
    │   ├── FileWriteTool（M7，high → Approval）
    │   ├── CommandExecuteTool（M7，high → Approval，H7 危险命令拦截）
    │   ├── GitTools（M7，push/reset/rebase high → Approval）
    │   ├── BuildTestTools（M7，复用 M4）
    │   ├── MCPToolAdapter（M8，适配 AgentTool，H15）
    │   └── SkillExecutor（M8，经 ActionExecutor，H16）
    ├── AuthorizationGate（M7，H12）
    └── AuditService（M7，H14，AuditTarget: agent/mcp/skill/rule/...）
```

### 6.2 M11 边界

**M11 复用 M8 既有接入关系，不另建旁路**。

- M11 不修改 M8 MCP/Skills/Rules 任何源文件
- M11 新增的 G-AI / CodeArts Agent 工具调用必须经此同一接入路径
- M11 不允许 G-AI / CodeArts Agent 绕过 ToolRegistry 直接调用 MCP/Skill
- M11 不允许 G-AI / CodeArts Agent 绕过 RuleEnforcer（Rules 约束对 AI 生成的 Plan 同样适用）

---

## 7. Authorization Chain

### 7.1 P0-07 回答：所有副作用如何经过 M7/M9 Authorization

#### 7.1.1 既有授权链路

**M7 Agent 副作用**：
```
M7 ActionExecutor
    ↓
M7 AuthorizationGateImpl（H12）
    ├── readOnly → 自动放行并记录
    ├── low → 自动放行并记录
    └── high → 强制审批（Approval Gate，H2 不可 bypass）
    ↓
M7 AuditService（H14）
```

**M9 Extension 副作用**：
```
M9 CapabilityAppService.invokeCapability
    ↓
M9 CapabilityContractRegistry.enforceContract（H21，无 Contract 拒绝）
    ↓
M9 ExtensionAuthorizationIntegration（H20，默认拒绝）
    ↓
M7 AuthorizationGate（H12，复用）
    ↓
M7 AuditService（H14，H23 复用）
```

**M8 MCP/Skill 副作用**：
```
M8 MCPToolAdapter / SkillExecutor
    ↓
M7 ActionExecutor（复用）
    ↓
M7 AuthorizationGate（H12，H15/H16）
    ↓
M7 AuditService（H14，H18）
```

#### 7.1.2 统一授权链路

```
任意副作用（Agent / Extension / MCP / Skill / G-AI / CodeArts Agent）
    ↓
Capability resolution（如果是 Extension/Capability）
    ↓
Contract validation（H21，如果是 Capability）
    ↓
M7 AuthorizationGate（H12，统一入口）
    ├── readOnly / low → 自动放行 + 审计
    └── high → Approval Gate（H2 不可 bypass）
        ↓
    User approval（high）
        ↓
Execution
    ↓
M7 AuditService（H14，统一入口，无第二套审计）
```

#### 7.1.3 授权链路的关键不可绕过点

| 检查点 | 硬约束 | 不可绕过机制 |
|--------|--------|-------------|
| Approval Gate | H2 | M0 ApprovalService 未修改，无 bypass 配置项 |
| Agent Authorization | H12 | `AuthorizationGateImpl`：high 强制审批 |
| Tool Isolation | H13 | `AgentTool` 协议仅返回 `ToolOutput`，不暴露底层类型 |
| Extension Authorization | H20 | 默认拒绝 + 高危二次审批 + Adapter 不可 bypass |
| Capability Contract | H21 | `enforceContract` 强制，无 Contract 不执行 |
| Adapter Isolation | H22 | `PublicProtocolSurface` + `BoundaryService`，IPC JSON-RPC |
| AI Approval Boundary | H9 | `AIBoundaryValidator`，允许集与禁止集互斥 |

### 7.2 M11 Authorization Chain

**M11 不修改任何既有授权组件**，仅新增"AI 工具调用 → 既有授权链路"的桥接。

**M11 新增桥接**（P4 阶段）：
```
G-AI / CodeArts Agent 生成的工具调用
    ↓
M11 AICapabilityAuthorizationBridge（新协议，P4 定义）
    ↓
M7 AuthorizationGate（H12，复用）或 M9 ExtensionAuthorizationIntegration（H20，复用）
    ↓
M7 AuditService（H14，复用）
```

**M11 不**：
- 不修改 M7 `AuthorizationGateImpl`
- 不修改 M9 `ExtensionAuthorizationIntegration`
- 不修改 M0 `ApprovalService`
- 不创建第二套授权系统
- 不允许任何 AI 生成动作绕过此链路（H28）

---

## 8. Audit Chain

### 8.1 P0-08 回答：G-AI 请求、工具调用、结果如何进入统一 Audit

#### 8.1.1 既有审计体系

**统一审计入口**：M7 `AuditService.record(AgentAuditRecord)`

**AgentAuditRecord**（M7，H14）：
- 8 字段 + SHA-256
- `AuditLogStore` JSONL 追加写

**AuditTarget 扩展历史**：

| 里程碑 | AuditTarget 扩展 | 硬约束 |
|--------|-----------------|--------|
| M7 | agent / tool / authorization / approval / session / plan / action / audit | H14 |
| M8 | mcp / skill / rule | H18 |
| M9 | extension / adapter / capability / contractNegotiation / permissionDecision | H23 |
| M10 | 复用 M9（22 EventKinds → M7 AgentAuditRecord） | H23 |

#### 8.1.2 G-AI 请求/工具调用/结果的审计路径

**G-AI 推理请求审计**：
```
G-AI 推理请求
    ↓
M6 ChatOrchestrator
    ↓
M6 AIBoundaryValidator（H9）
    ↓
M7 AuditService.record（AuditTarget: aiInference，M11-P5 新增）
    ↓
推理结果（含 token usage、latency、model endpoint）
```

**G-AI / CodeArts Agent 工具调用审计**：
```
G-AI / CodeArts Agent 生成的工具调用
    ↓
M7 ActionExecutor 或 M9 CapabilityAppService.invokeCapability
    ↓
M7 AuditService.record（AuditTarget: agent/tool/mcp/skill/...，既有）
    ↓
工具调用结果（含输入、输出、SHA-256、耗时）
```

**G-AI 流程驱动审计**（M11 新增）：
```
G-AI 流程任务（SPEC→DESIGN→...→GATE）
    ↓
M11 GAIRuntimeBridge
    ↓
M7 AuditService.record（AuditTarget: gaiRuntime，M11-P5 新增）
    ↓
流程状态推进（含阶段、证据链、Gate 结果）
```

#### 8.1.3 审计链路的关键原则

1. **单一审计入口**：所有审计经 M7 `AuditService.record`，无第二套审计系统（H23 原则）
2. **SHA-256 完整性**：每条审计记录含 SHA-256 摘要（H14）
3. **JSONL 追加写**：`AuditLogStore` 追加写，不可篡改
4. **8 字段强制**：每条 `AgentAuditRecord` 含 8 字段（H14）
5. **AuditTarget 全覆盖**：agent/tool/mcp/skill/rule/extension/adapter/capability/.../aiInference/gaiRuntime

### 8.2 M11 Audit Chain 扩展

**M11 新增 AuditTarget**（P5 阶段）：
- `aiInference`：G-AI 推理请求/响应审计
- `gaiRuntime`：G-AI 流程驱动审计（SPEC→DESIGN→...→GATE 各阶段）
- `aiToolCall`：AI 生成的工具调用审计（区别于人类发起的工具调用）

**M11 不**：
- 不创建第二套审计系统（H23）
- 不修改 M7 `AuditService` / `AuditLogStore` / `AgentAuditRecord` 核心结构
- 仅扩展 `AuditTarget` 枚举（追加 case），不破坏既有结构

---

## 9. H28 AI Execution Boundary

### 9.1 硬约束定义

**H28 — AI Execution Boundary**

**定义**：任何 G-AI / CodeArts Agent 生成的工具调用，都不能绕过 AppKCode 既有 Authorization、Capability Contract 和 Audit。

**形式化表述**：
```
∀ action ∈ AIGeneratedActions:
    action 必须经以下链路，不得有任何 bypass 路径：

    AI-generated action
            ↓
    Capability resolution（如果是 Capability）
            ↓
    Contract validation（H21，如果是 Capability）
            ↓
    Authorization（H12/H20，统一 AuthorizationGate）
            ↓
    User approval（high，H2 不可 bypass）
            ↓
    Execution
            ↓
    Audit（H14/H23，统一 AuditService）
```

### 9.2 H28 验收条件

| 编号 | 验收条件 | 验证方式 |
|------|---------|---------|
| H28-1 | G-AI 推理请求经 M6 ModelProvider + AIBoundaryValidator（H9） | 集成测试：G-AI 请求路径断言 |
| H28-2 | G-AI / CodeArts Agent 工具调用经 M7 ToolRegistry | 集成测试：工具调用路径断言 |
| H28-3 | AI 生成的高危操作经 M7 AuthorizationGate（H12）强制审批 | 集成测试：高危操作拦截 |
| H28-4 | AI 生成的 Capability 调用经 M9 enforceContract（H21） | 集成测试：无 Contract 拒绝 |
| H28-5 | AI 生成的 Extension 调用经 M9 ExtensionAuthorizationIntegration（H20） | 集成测试：默认拒绝 |
| H28-6 | 所有 AI 生成动作经 M7 AuditService（H14）审计 | 集成测试：审计记录存在性 |
| H28-7 | 不存在 AI → Shell 直接执行路径 | 源码审查 + 测试：无 bypass |
| H28-8 | 不存在 AI → Git 直接执行路径 | 源码审查 + 测试：无 bypass |
| H28-9 | 不存在 AI → File 直接写入路径 | 源码审查 + 测试：无 bypass |
| H28-10 | 不存在第二套审计系统 | 源码审查：单一 AuditService |

### 9.3 H28 与既有硬约束的关系

```
H2  (Approval Gate 不可 bypass)     ─┐
H9  (AI Approval Boundary)          ─┤
H12 (Agent Authorization)           ─┤
H13 (Tool Isolation)                ─┤
H14 (Agent Audit)                   ─┤
H20 (Extension Authorization)       ─┼─→ H28 (AI Execution Boundary)
H21 (Capability Contract)           ─┤
H22 (Adapter Isolation)             ─┤
H23 (Compatibility Audit)           ─┤
H15 (MCP Isolation)                 ─┤
H16 (Skill Isolation)               ─┘
```

**H28 是上述既有硬约束在 AI 集成层的统一表述**，不替代任何既有约束，而是确保 AI 集成不引入新的 bypass 路径。

### 9.4 H28 禁止项

- ❌ 禁止 AI 生成的动作绕过 AuthorizationGate
- ❌ 禁止 AI 生成的动作绕过 CapabilityContractRegistry.enforceContract
- ❌ 禁止 AI 生成的动作绕过 AuditService
- ❌ 禁止 AI 生成的动作绕过 Approval Gate（高危）
- ❌ 禁止 AI → Shell 直接执行
- ❌ 禁止 AI → Git 直接执行
- ❌ 禁止 AI → File 直接写入
- ❌ 禁止第二套审计系统

---

## 10. x86_64 约束

### 10.1 既有约束（H1）

- **H1 — x86_64 Architecture Only**：所有原生二进制必须为 `x86_64-apple-macos13.0`
- M10 验证：`file .build/release/AppKCode` → `Mach-O 64-bit executable x86_64` ✅
- arch-check.sh → `ARCH CHECK PASSED - All binaries are x86_64` ✅

### 10.2 M11 x86_64 约束

**M11 保持 H1 约束不变**：
- M11 新增的所有 Swift 代码必须构建为 `x86_64-apple-macos13.0`
- M11 不引入 ARM64-only 依赖
- M11 不引入 ARM64 二进制强行加载到 x86_64
- M11 构建产物经 arch-check.sh 校验

### 10.3 M11 禁止项

- ❌ 禁止引入 ARM64-only 原生依赖
- ❌ 禁止 ARM64 二进制强行加载到 x86_64
- ❌ 禁止修改构建目标三元组（保持 `x86_64-apple-macos13.0`）
- ❌ 禁止修改 arch-check.sh

---

## 11. M10 Frozen Baseline 保护

### 11.1 Frozen 基线状态

| 里程碑 | Commit | Tests | 状态 |
|--------|--------|-------|------|
| M0 | `66a78fc` | 30/30 | ✅ FROZEN |
| M1 | `eccb894` | 52/52 | ✅ FROZEN |
| M2 | `84e50a2` | 105/105 | ✅ FROZEN |
| M3 | `30fed8a` | 165/165 | ✅ FROZEN |
| M4 | `bca4fe3` | 278/278 | ✅ FROZEN |
| M5 | `c5024f1` | 392/392 | ✅ FROZEN |
| M6 | `27b0824` | 489/489 | ✅ FROZEN |
| M7 | `e19170b` | 545/545 | ✅ FROZEN |
| M8 | `c2a982a` | 586/586 | ✅ FROZEN |
| M9 | `23579c2` | 625/625 | ✅ FROZEN |
| M10 | `81bb91f` | 1103/1103 | ✅ FROZEN |

### 11.2 M11 基线保护规则

**M11 不修改 M0-M10 任何源文件或测试文件**：

| 层 | M11 不修改的文件 | M11 可新增的文件 |
|----|-----------------|-----------------|
| Shared | M0-M10 所有 Shared 类型文件 | M11 新增 Shared 类型（如 AuditTarget 扩展 case） |
| Infrastructure | M0-M10 所有 Infra 实现 | M11 新增 Infra 实现（如 GAIRuntimeBridge） |
| Domain | M0-M10 所有 Domain 实现 | M11 新增 Domain 实现（如 AICapabilityAuthorizationBridge） |
| Application | M0-M10 所有 App 编排 | M11 新增 App 编排（如 GAIIntegrationOrchestrator） |
| Presentation | M0-M10 所有 UI | M11 新增 UI（如 GAIRuntimePanelView） |
| Tests | M0-M10 所有测试文件 | M11 新增测试文件 |

**例外**（M11 仅可追加，不修改语义）：
- `AuditTarget` 枚举：追加 `aiInference` / `gaiRuntime` / `aiToolCall` case（不修改既有 case）
- `ToolCategory` 枚举：追加 M11 新工具类别（如有需要，不修改既有 case）

### 11.3 M11 禁止项

- ❌ 禁止修改 M0-M10 任何源文件语义
- ❌ 禁止修改 M0-M10 任何测试文件
- ❌ 禁止 reset / amend / force push 已有 Frozen Commit
- ❌ 禁止修改 M10 commit `81bb91f`
- ❌ 禁止修改 M9 commit `23579c2`
- ❌ 禁止修改任何 M0-M8 Frozen Commit

### 11.4 M11 回归验证

M11 每阶段 Exit Gate 必须验证：
- `swift build` → 0 errors
- `swift test` → M0-M10 既有 1103 tests 全部 PASS + M11 新增 tests PASS
- `arch-check.sh` → x86_64
- M10 commit `81bb91f` 源文件 0 modified（git diff 校验）
- M9 commit `23579c2` 源文件 0 modified

---

## 12. M11 Phase 划分

### 12.1 Phase 总览

```
M11-P0  Integration Scope Review          ← 本文档
   ↓
M11-P1  G-AI Provider / API Contract      ← 定义 G-AI 流程驱动接口
   ↓
M11-P2  Agent Context Bridge              ← G-AI / CodeArts Agent 上下文桥接
   ↓
M11-P3  Agent ↔ MCP / Skills / Rules      ← AI 工具调用接入既有 ToolRegistry
   ↓
M11-P4  AI Capability Authorization       ← H28 授权桥接
   ↓
M11-P5  AI Tool Execution + Audit         ← H28 审计桥接
   ↓
M11-P6  CodeArts Agent Integration        ← CodeArts Agent 工作流集成
   ↓
M11-P7  End-to-End Agent Runtime          ← 端到端集成
   ↓
M11-P8  Final Integration / Regression / Exit  ← 最终验收
```

### 12.2 各 Phase 范围

#### M11-P0: Integration Scope Review（本文档）
- **输入**：M0-M10 全部 exit report + spec.md + design.md
- **输出**：`m11_scope_review.md`
- **不编码**：仅文档
- **Exit Gate**：PM 审核通过 + 授权 P1

#### M11-P1: G-AI Provider / API Contract
- **目标**：定义 G-AI Runtime 流程驱动接口（`GAIRuntimeBridge` 协议）
- **范围**：
  - 定义 `GAIRuntimeBridge` 协议（SPEC→DESIGN→TASK→...→GATE 状态机桥接）
  - 定义 G-AI 流程任务类型（`GAIWorkflowTask` / `GAIWorkflowState`）
  - 复用 M6 `ModelProvider` / `ModelProviderRegistry` / `AIBoundaryValidator`（不修改）
  - 复用 M7 `AgentRuntimeOrchestrator`（不修改）
- **硬约束**：H3/H9/H11/H28
- **不修改**：M6/M7 任何源文件

#### M11-P2: Agent Context Bridge
- **目标**：定义 G-AI / CodeArts Agent 请求上下文的 Bridge 接口
- **范围**：
  - 定义 `AgentContextBridge` 协议
  - 复用 M6 `ContextAggregator` + 8 个 `ContextProvider`（不修改）
  - CodeArts Agent 经 M9 `PublicProtocolSurface`（H22，不修改）
- **硬约束**：H10/H22/H28
- **不修改**：M6/M9 任何源文件

#### M11-P3: Agent ↔ MCP / Skills / Rules
- **目标**：确保 AI 生成的工具调用经 M8 既有接入路径
- **范围**：
  - 定义 `AIToolInvocationBridge`（AI 工具调用 → M7 ToolRegistry）
  - 复用 M8 `MCPToolAdapter` / `SkillExecutor` / `RuleEnforcer`（不修改）
  - Rules 约束对 AI 生成的 Plan 同样适用
- **硬约束**：H15/H16/H17/H28
- **不修改**：M7/M8 任何源文件

#### M11-P4: AI Capability Authorization
- **目标**：实现 H28 授权桥接
- **范围**：
  - 定义 `AICapabilityAuthorizationBridge` 协议
  - AI 工具调用 → M7 `AuthorizationGate`（H12）或 M9 `ExtensionAuthorizationIntegration`（H20）
  - AI Capability 调用 → M9 `enforceContract`（H21）
- **硬约束**：H2/H12/H20/H21/H28
- **不修改**：M0/M7/M9 任何源文件

#### M11-P5: AI Tool Execution + Audit
- **目标**：实现 H28 审计桥接
- **范围**：
  - 扩展 `AuditTarget`：追加 `aiInference` / `gaiRuntime` / `aiToolCall` case
  - AI 推理请求审计 → M7 `AuditService`（H14）
  - AI 工具调用审计 → M7 `AuditService`（H14）
  - AI 流程驱动审计 → M7 `AuditService`（H14）
- **硬约束**：H14/H18/H23/H28
- **不修改**：M7 `AuditService` / `AuditLogStore` / `AgentAuditRecord` 核心结构（仅扩展 AuditTarget 枚举）

#### M11-P6: CodeArts Agent Integration
- **目标**：CodeArts Agent 工作流集成
- **范围**：
  - 评估 CodeArts Adapter 是否深化（M9 Foundation → 真实实现）
  - 复用 M10 `VSCodeExtensionHostAdapter` / `JetBrainsPluginHostAdapter`（不修改）
  - CodeArts Agent → M9 `CapabilityAppService.invokeCapability`（H19 全链路）
- **硬约束**：H19/H20/H21/H22/H23/H24/H25/H26/H27/H28
- **不修改**：M9/M10 任何源文件
- **不宣称**：所有 CodeArts 插件完全兼容

#### M11-P7: End-to-End Agent Runtime
- **目标**：端到端集成验证
- **范围**：
  - G-AI → Agent → Tool → Contract → Auth → Exec → Audit 全链路
  - CodeArts Agent → Adapter → Contract → Auth → Exec → Audit 全链路
  - 端到端集成测试
- **硬约束**：H28 + H1-H27 全部
- **不修改**：M0-M10 任何源文件

#### M11-P8: Final Integration / Regression / Exit
- **目标**：最终验收 + Exit Report
- **范围**：
  - `swift build` → 0 errors
  - `swift test` → M0-M10 既有 1103 tests + M11 新增 tests 全部 PASS
  - `arch-check.sh` → x86_64
  - M10 `81bb91f` 基线 0 modified
  - H28 全部验收条件 PASS
  - 生成 `m11_exit_report.md`
- **硬约束**：H1-H28 全部

---

## 13. 每阶段 Exit Gate

### 13.1 Exit Gate 通用标准

每个 Phase 的 Exit Gate 必须满足：
1. `swift build` → 0 errors
2. `swift test` → M0-M10 既有 1103 tests 全部 PASS + 本 Phase 新增 tests PASS
3. `arch-check.sh` → x86_64（H1）
4. M10 commit `81bb91f` 源文件 0 modified（git diff 校验）
5. 本 Phase 硬约束验收 PASS
6. 本 Phase 不引入禁止项

### 13.2 各 Phase Exit Gate

| Phase | Exit Gate | 硬约束 | 产出 |
|-------|-----------|--------|------|
| P0 | PM 审核通过 + 授权 P1 | — | `m11_scope_review.md` |
| P1 | `GAIRuntimeBridge` 协议定义 + 测试 PASS | H3/H9/H11/H28 | spec + design + tests |
| P2 | `AgentContextBridge` 协议定义 + 测试 PASS | H10/H22/H28 | spec + design + tests |
| P3 | `AIToolInvocationBridge` + 测试 PASS | H15/H16/H17/H28 | spec + design + tests |
| P4 | `AICapabilityAuthorizationBridge` + H28-3/4/5 验收 PASS | H2/H12/H20/H21/H28 | spec + design + tests |
| P5 | AuditTarget 扩展 + H28-6/10 验收 PASS | H14/H18/H23/H28 | spec + design + tests |
| P6 | CodeArts Agent 集成 + H19-H24 验收 PASS | H19-H28 | spec + design + tests |
| P7 | 端到端集成测试 PASS | H1-H28 | integration tests |
| P8 | 全量回归 + Exit Report | H1-H28 | `m11_exit_report.md` |

### 13.3 P0 Exit Gate（本文档）

| 检查项 | 状态 |
|--------|------|
| 8 个核心问题（P0-01 ~ P0-08）全部回答 | ✅（见 §4-§8） |
| H28 AI Execution Boundary 定义 | ✅（见 §9） |
| x86_64 约束明确 | ✅（见 §10） |
| M10 Frozen Baseline 保护规则明确 | ✅（见 §11） |
| M11 Phase 划分明确 | ✅（见 §12） |
| 每阶段 Exit Gate 明确 | ✅（见 §13.2） |
| 明确禁止事项列出 | ✅（见 §15） |
| 是否具备授权 P1 的条件判定 | ✅（见 §14） |
| 不修改 M0-M10 任何源文件 | ✅（本文档仅文档） |
| 不创建任何 Swift 代码 | ✅（本文档仅文档） |

---

## 14. 是否具备授权 P1 的条件

### 14.1 授权 P1 的前置条件检查

| 编号 | 前置条件 | 状态 | 证据 |
|------|---------|------|------|
| C1 | M0-M10 全部 PASS / CLOSED / FROZEN | ✅ | M10 exit report: 1103/1103 tests PASS |
| C2 | M10 FROZEN commit `81bb91f` 基线稳定 | ✅ | M10 exit report: Working Tree Clean |
| C3 | M9 FROZEN commit `23579c2` 基线稳定 | ✅ | M10 exit report: M9 23579c2 Frozen ✅ Unmodified |
| C4 | H1-H27 全部 PASS | ✅ | M10 exit report: H1/H19-H27 全部 PASS |
| C5 | x86_64 架构锁定 | ✅ | M10 exit report: arch-check → x86_64 |
| C6 | P0-01 ~ P0-08 全部回答 | ✅ | 本文档 §4-§8 |
| C7 | H28 AI Execution Boundary 定义 | ✅ | 本文档 §9 |
| C8 | M11 Phase 划分明确 | ✅ | 本文档 §12 |
| C9 | 每阶段 Exit Gate 明确 | ✅ | 本文档 §13 |
| C10 | 明确禁止事项列出 | ✅ | 本文档 §15 |
| C11 | G-AI 推理接口已由 M6 实现 | ✅ | M6 exit report: ModelProvider/OpenAICompatProvider/LocalModelProvider |
| C12 | Agent Runtime 已由 M7 实现 | ✅ | M7 exit report: AgentRuntimeOrchestrator/AuthorizationGate/AuditService |
| C13 | MCP/Skills/Rules 已由 M8 实现 | ✅ | M8 exit report: MCPHostService/SkillRegistry/RuleEngine |
| C14 | Compatibility Foundation 已由 M9 实现 | ✅ | M9 exit report: CapabilityAppService/RuntimeAdapter |
| C15 | VS Code/JetBrains Compatibility 已由 M10 实现 | ✅ | M10 exit report: VSCodeExtensionHostAdapter/JetBrainsPluginHostAdapter |
| C16 | 本文档不修改 M0-M10 任何源文件 | ✅ | 本文档仅文档 |
| C17 | 本文档不创建任何 Swift 代码 | ✅ | 本文档仅文档 |
| C18 | PM 审核本文档通过 | ⏳ | **待 PM 审核** |

### 14.2 授权 P1 的条件判定

**判定逻辑**：
- C1-C17 全部 ✅ → 技术条件满足
- C18 ⏳ → PM 审核是最终授权条件

**结论**：

> **技术条件**：✅ 全部满足（C1-C17）
> **PM 审核**：⏳ 待 PM 审核本文档
> **授权 P1**：当且仅当 PM 审核本文档通过（C18 ✅）后，授权 M11-P1 启动

### 14.3 P1 启动前的 PM 审核要点

PM 应重点审核：
1. H28 AI Execution Boundary 定义是否覆盖所有 AI 生成动作路径
2. G-AI Integration Boundary 是否明确（不绕过既有授权/审计）
3. CodeArts Agent Boundary 是否明确（不拥有独立授权/审计）
4. M11 Phase 划分是否合理（P1-P8 依赖关系）
5. 每阶段 Exit Gate 是否可验证
6. 明确禁止事项是否完整
7. M10 Frozen Baseline 保护规则是否严格
8. x86_64 约束是否保持

---

## 15. 明确禁止事项

### 15.1 M11 全局禁止事项

```
❌ 自主 Agent 无限循环
❌ 自动修改整个项目
❌ 自动执行 Shell
❌ 自动 Git Commit
❌ 自动 Git Push
❌ 自动部署
❌ 绕过用户 Approval
❌ 私有 CodeArts API 逆向
❌ 宣称"所有 CodeArts 插件完全兼容"
❌ ARM64 二进制强行加载到 x86_64
❌ 修改 M0-M10 Frozen 基线
❌ reset / amend 已有 Frozen Commit
```

### 15.2 M11 技术禁止事项

| 编号 | 禁止事项 | 硬约束 |
|------|---------|--------|
| B1 | 禁止 AI 生成的动作绕过 AuthorizationGate | H28/H12/H2 |
| B2 | 禁止 AI 生成的动作绕过 CapabilityContractRegistry.enforceContract | H28/H21 |
| B3 | 禁止 AI 生成的动作绕过 AuditService | H28/H14/H23 |
| B4 | 禁止 AI 生成的动作绕过 Approval Gate（高危） | H28/H2 |
| B5 | 禁止 AI → Shell 直接执行 | H28/H7 |
| B6 | 禁止 AI → Git 直接执行 | H28/H8 |
| B7 | 禁止 AI → File 直接写入 | H28/H12 |
| B8 | 禁止第二套审计系统 | H23/H28 |
| B9 | 禁止第二套授权系统 | H12/H28 |
| B10 | 禁止 G-AI Runtime 绕过 M6 ModelProvider | H28/H9/H11 |
| B11 | 禁止 G-AI Runtime 绕过 M6 AIBoundaryValidator | H28/H9 |
| B12 | 禁止 G-AI Runtime 自主无限循环 | §15.1 |
| B13 | 禁止 CodeArts Agent 拥有独立 Authorization | H20/H28 |
| B14 | 禁止 CodeArts Agent 拥有独立 Audit | H23/H28 |
| B15 | 禁止 CodeArts Agent 直接访问宿主内部 | H22/H28 |
| B16 | 禁止引入 ARM64-only 依赖 | H1 |
| B17 | 禁止修改构建目标三元组 | H1 |
| B18 | 禁止修改 M0-M10 任何源文件语义 | §11 |
| B19 | 禁止修改 M0-M10 任何测试文件 | §11 |
| B20 | 禁止 reset / amend / force push Frozen Commit | §11 |

### 15.3 M11 不宣称事项

- ❌ 不宣称"所有 CodeArts 插件完全兼容"
- ❌ 不宣称"所有 VS Code 插件完全兼容"
- ❌ 不宣称"所有 JetBrains 插件完全兼容"
- ❌ 不宣称"私有 CodeArts API 逆向兼容"
- ❌ 不宣称"G-AI Runtime 全流程自主完成"（必须经用户审批）
- ❌ 不宣称"AI Agent 可替代人类决策"（高危必须人工审批）

---

## 16. P0-01 ~ P0-08 回答汇总

| 编号 | 问题 | 回答章节 | 核心结论 |
|------|------|---------|---------|
| P0-01 | G-AI Runtime 的实际接口是什么 | §4.1 | 推理接口已由 M6 实现（OpenAI-compatible）；流程驱动接口 M11-P1 定义 |
| P0-02 | Local Model / OpenAI-compatible API 如何接入 | §4.2 | 已由 M6 完整实现，M11 复用不重新实现 |
| P0-03 | CodeArts Agent 与 AppKCode Agent 的职责边界 | §3.2 | CodeArts Agent 不拥有独立 Auth/Audit，经 M9 → M7 统一链路 |
| P0-04 | MCP / Skills / Rules 如何进入 Agent Loop | §6.1 | 已由 M8 完整实现，M11 复用不另建旁路 |
| P0-05 | Agent 如何读取 Workspace / Editor / Diagnostics | §5.1 | 已由 M6 ContextAggregator + 8 Provider 实现，M11 复用 |
| P0-06 | Agent 如何提出 Patch / Command / Git 操作 | §7.1.1 | 已由 M7 ToolRegistry + AgentTool 实现，M11 复用 + H28 桥接 |
| P0-07 | 所有副作用如何经过 M7/M9 Authorization | §7.1 | 统一 AuthorizationGate（H12/H20）+ AuditService（H14/H23） |
| P0-08 | G-AI 请求、工具调用、结果如何进入统一 Audit | §8.1 | 单一 AuditService.record 入口，M11 扩展 AuditTarget 不创建第二套 |

---

## 17. 集成架构总图

```
                    ┌─────────────────────────────────┐
                    │           AppKCode M11           │
                    └────────────┬────────────────────┘
                                 │
              ┌──────────────────┴──────────────────┐
              │                                     │
     ┌────────┴────────┐                ┌───────────┴───────────┐
     │  CodeArts Agent  │                │     G-AI Runtime      │
     │  (M9/M10 Adapter)│                │  (M6 ModelProvider)   │
     └────────┬────────┘                └───────────┬───────────┘
              │                                     │
              │   ┌─────────────────────────────────┘
              │   │
              ▼   ▼
     ┌─────────────────────────┐
     │  M11 Agent Orchestrator  │  ← M7 AgentRuntimeOrchestrator（复用）
     │  + G-AI Bridge (P1)      │  ← M11 GAIRuntimeBridge（新增）
     │  + Context Bridge (P2)   │  ← M11 AgentContextBridge（新增）
     └────────────┬────────────┘
                  │
         ┌────────┴────────┐
         │                 │
         ▼                 ▼
 ┌──────────────┐  ┌──────────────────────┐
 │  M7 Planner  │  │  M8 RuleEnforcer     │  ← Rules 约束（H17）
 │  → ActionPlan│  │  (apply to Plan)     │
 └──────┬───────┘  └──────────────────────┘
        │
        ▼
 ┌──────────────────────────────────────────┐
 │  M7 ActionExecutor                        │
 │  ├── FileReadTool (M7, readOnly)          │
 │  ├── FileWriteTool (M7, high → Approval) │
 │  ├── CommandExecuteTool (M7, high, H7)   │
 │  ├── GitTools (M7, push/reset → Approval)│
 │  ├── BuildTestTools (M7, 复用 M4)        │
 │  ├── MCPToolAdapter (M8, H15)            │
 │  └── SkillExecutor (M8, H16)             │
 └──────────────────┬───────────────────────┘
                    │
                    ▼
 ┌──────────────────────────────────────────┐
 │  M9 CapabilityContractRegistry            │  ← H21 enforceContract
 │  (如果是 Capability 调用)                  │
 └──────────────────┬───────────────────────┘
                    │
                    ▼
 ┌──────────────────────────────────────────┐
 │  M7 AuthorizationGate (H12)              │  ← 统一授权
 │  / M9 ExtensionAuthorizationIntegration  │  ← H20（Extension）
 │  ├── readOnly/low → 自动放行              │
 │  └── high → Approval Gate (H2 不可 bypass)│
 └──────────────────┬───────────────────────┘
                    │
                    ▼
 ┌──────────────────────────────────────────┐
 │  Execution                                │
 │  ├── M7 AgentTool.execute                 │
 │  └── M9 RuntimeAdapter.invokeCapability   │
 └──────────────────┬───────────────────────┘
                    │
                    ▼
 ┌──────────────────────────────────────────┐
 │  M7 AuditService (H14)                    │  ← 统一审计（单一入口）
 │  AuditTarget: agent/tool/mcp/skill/rule/  │
 │  extension/adapter/capability/.../        │
 │  aiInference/gaiRuntime/aiToolCall (M11)  │
 └──────────────────────────────────────────┘
```

---

## 18. 结论

### 18.1 P0 Scope Review 完成状态

| 检查项 | 状态 |
|--------|------|
| M11 目标明确 | ✅ |
| G-AI Integration Boundary 明确 | ✅ |
| CodeArts Agent Boundary 明确 | ✅ |
| Provider/API Contract 明确 | ✅ |
| Agent Context Contract 明确 | ✅ |
| MCP/Skills/Rules 接入关系明确 | ✅ |
| Authorization Chain 明确 | ✅ |
| Audit Chain 明确 | ✅ |
| H28 AI Execution Boundary 定义 | ✅ |
| x86_64 约束明确 | ✅ |
| M10 Frozen Baseline 保护规则明确 | ✅ |
| M11 Phase 划分明确 | ✅ |
| 每阶段 Exit Gate 明确 | ✅ |
| 明确禁止事项列出 | ✅ |
| 是否具备授权 P1 的条件判定 | ✅（技术条件满足，待 PM 审核） |

### 18.2 核心原则确认

```
G-AI → Agent → Tool/Capability → Contract → Authorization → Execution → Audit
```

**而非**：`G-AI → Shell → 随意执行`

✅ 本文档确保所有 AI 生成动作经统一链路，H28 AI Execution Boundary 强制不可绕过。

### 18.3 授权 P1 判定

> **技术条件**：✅ 全部满足（C1-C17）
> **PM 审核**：⏳ 待 PM 审核本文档
> **授权 P1**：当且仅当 PM 审核本文档通过（C18 ✅）后，授权 M11-P1 启动

### 18.4 M11 不变性

M11 全程保持以下不变性：
1. **H1 不变**：x86_64-apple-macos13.0
2. **H2 不变**：Approval Gate 不可 bypass
3. **H12 不变**：Agent Authorization 强制
4. **H14 不变**：Agent Audit 单一入口
5. **H23 不变**：无第二套审计系统
6. **M10 `81bb91f` 不变**：Frozen 基线保护
7. **M9 `23579c2` 不变**：Frozen 基线保护
8. **H28 新增**：AI Execution Boundary 强制

---

> **M11-P0 Scope Review 完成**。本文档定义了 G-AI / CodeArts Agent 集成层的完整边界、H28 AI Execution Boundary、M11 Phase 划分和授权 P1 的条件。请求 PM 审核本文档，裁定是否授权 M11-P1 启动。
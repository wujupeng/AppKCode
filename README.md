# AppKCode

**AI 原生 IDE，面向 Intel Mac (macOS 13.0, x86_64)**

AppKCode 是一个基于 Swift 构建的 AI 原生集成开发环境，功能对齐华为云 CodeArts Agent IDE。项目采用四层 Clean Architecture，支持 VS Code Extension 和 JetBrains Plugin 双生态兼容，内置 AI Agent Runtime、MCP 协议、LSP、Git、Terminal 等完整 IDE 能力。

## 目录

- [特性](#特性)
- [技术栈](#技术栈)
- [架构](#架构)
- [功能模块](#功能模块)
- [构建与运行](#构建与运行)
- [测试](#测试)
- [CI/CD](#cicd)
- [里程碑](#里程碑)
- [硬约束](#硬约束)
- [项目结构](#项目结构)
- [许可证](#许可证)

## 特性

- **AI 原生**：内置 Agent Runtime，支持多轮对话、工具调用、上下文构建、自动审批
- **双生态兼容**：同时支持 VS Code Extension（36 API）和 JetBrains Plugin（9 OpenAPI / 24 方法），通过 Shim 层实现 API 映射
- **进程隔离**：Extension/Plugin 运行在独立子进程中，崩溃自动恢复（3 秒重启，60 秒内超 3 次停止）
- **安全沙箱**：Agent 工具隔离、权限分级（readOnly/low/high）、全量审计日志
- **MCP 协议**：完整实现 Model Context Protocol，支持 stdio/HTTP 传输
- **LSP 集成**：Language Server Protocol 客户端，支持补全/Hover/定义/诊断
- **Git 集成**：内置 Git 状态管理、diff 解析、分支操作
- **Terminal**：VT100 解析器 + PTY 管理，内置终端面板
- **Build/Test**：构建系统集成、测试报告解析
- **Codebase Index**：基于 ripgrep 的代码索引与搜索

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.8 |
| UI 框架 | SwiftUI + AppKit |
| 包管理 | Swift Package Manager (SPM) |
| 平台 | macOS 13.0+ (Ventura) |
| 架构 | x86_64 (Intel Mac only) |
| 持久化 | JSONL + SQLite |
| 加密 | CryptoKit (SHA256) |
| 构建 | `x86_64-apple-macos13.0` |

## 架构

AppKCode 采用四层 Clean Architecture，依赖方向严格单向：

```
AppKCodeApp (入口)
    └── AppKCodePresentation (UI 层 — SwiftUI Views)
            └── AppKCodeApplication (应用服务编排)
                    └── AppKCodeDomain (领域模型 + 业务逻辑)
                            └── AppKCodeInfrastructure (基础设施实现)
                                    └── AppKCodeShared (共享类型 + 协议)
```

### 层级职责

| 层 | Target | 职责 |
|----|--------|------|
| **Shared** | `AppKCodeShared` | 共享类型、协议、错误定义、值对象 |
| **Infrastructure** | `AppKCodeInfrastructure` | 文件系统、进程、网络、Git CLI、LSP 客户端、PTY、审计存储 |
| **Domain** | `AppKCodeDomain` | 领域模型、业务规则、服务接口、Agent Runtime、Compatibility Registry |
| **Application** | `AppKCodeApplication` | 服务编排、Agent Orchestrator、Tool Router、Approval Service |
| **Presentation** | `AppKCodePresentation` | SwiftUI Views、ViewModels、UI 状态管理 |
| **App** | `AppKCodeApp` | `@main` 入口点 |

### 插件层

| Target | 职责 |
|--------|------|
| `AppKCodeExtensionHost` | Extension Host 进程管理、Supervisor、Resource Limiter、IPC Channel |
| `AppKCodePluginVSCode` | VS Code API Shim（6 JS 模块：extension-host, vscode-shim, workspace-fs, window-commands, base-types, languages-extensions） |
| `AppKCodePluginJetBrains` | JetBrains OpenAPI Shim（3 JS 模块：plugin-host, openapi-shim, classloader-isolation） |
| `AppKCodePluginNative` | Native 插件支持 |

## 功能模块

| 模块 | 说明 | 里程碑 |
|------|------|--------|
| **Editor Core** | 文本编辑、补全、Hover、代码动作 | M1 |
| **Git / Source Control** | 状态管理、diff、分支、提交 | M2, M5 |
| **LSP** | Language Server Protocol 客户端 | M3 |
| **Terminal / PTY** | VT100 终端、PTY 进程管理 | M4 |
| **AI Chat / Context** | 多轮对话、上下文构建、模型路由 | M6 |
| **Agent Runtime** | Agent 编排、工具隔离、授权、审计 | M7 |
| **MCP / Skills / Rules** | MCP 协议、技能系统、规则引擎 | M8 |
| **Compatibility Foundation** | Extension Manifest、Capability Contract、Version Negotiation | M9 |
| **VS Code / JetBrains Host** | Extension Host、API Shim、降级策略、进程隔离 | M10 |

## 构建与运行

### 前置条件

- macOS 13.0+ (Ventura)
- Xcode 15.0+ (含 Swift 5.8)
- Intel Mac (x86_64) — **不支持 Apple Silicon (ARM64)**

### 构建

```bash
# Debug 构建
swift build

# Release 构建
swift build -c release

# 指定架构
swift build --triple x86_64-apple-macos13.0
```

### 运行

```bash
# 从构建产物运行
.build/debug/AppKCode

# Release 版本
.build/release/AppKCode
```

### 架构检查

```bash
# 验证所有二进制为 x86_64
bash CI/arch-check.sh

# 检查是否有 ARM64 依赖
bash CI/arm-dep-check.sh
```

## 测试

```bash
# 运行全部测试
swift test

# 运行特定测试
swift test --filter VSCodeContractTests

# 运行并生成覆盖率
swift test --enable-code-coverage
```

### 测试结构

| 测试 Target | 说明 | 测试数 |
|-------------|------|--------|
| `AppKCodeSharedTests` | 共享类型测试 | 2 files |
| `AppKCodeDomainTests` | 领域模型测试 | 33 files |
| `AppKCodeInfrastructureTests` | 基础设施测试 | 8 files |
| `AppKCodeApplicationTests` | 应用服务测试 | 6 files |
| `AppKCodeExtensionHostTests` | Extension Host 测试 | 1 file |
| `AppKCodeIntegrationTests` | 集成测试（VS Code/JetBrains Contract + Hard Constraint） | 15 files |
| `AppKCodeContractTests` | 契约测试 | 1 file |

**当前状态：921/921 tests pass, 0 failures**

## CI/CD

| 脚本 | 用途 |
|------|------|
| `CI/arch-check.sh` | 验证所有二进制为 x86_64 架构 |
| `CI/arm-dep-check.sh` | 检查是否有 ARM64 依赖泄漏 |
| `CI/intel-build.yml` | Intel Mac 构建流水线 |
| `CI/intel-smoke-test.sh` | 冒烟测试 |
| `CI/release.yml` | 发布流水线 |

## 里程碑

| 里程碑 | 状态 | Commit | 测试数 | 说明 |
|--------|------|--------|--------|------|
| M0 | ✅ FROZEN | — | — | 项目基础、类型系统 |
| M1 | ✅ FROZEN | — | — | Editor Core |
| M2 | ✅ FROZEN | — | — | Git / Source Control |
| M3 | ✅ FROZEN | — | — | LSP Integration |
| M4 | ✅ FROZEN | — | — | Terminal / PTY |
| M5 | ✅ FROZEN | `e64b252` | — | Git Integration (full) |
| M6 | ✅ FROZEN | `27b0824` | 489 | AI Chat / Context Integration |
| M7 | ✅ FROZEN | `e19170b` | — | Agent Runtime & Authorization |
| M8 | ✅ FROZEN | `c2a982a` | — | MCP / Skills / Rules Runtime |
| M9 | ✅ FROZEN | `23579c2` | 625 | Compatibility Foundation |
| M10 | 🔄 进行中 | `1693202` | 921 | VS Code / JetBrains Extension Host (Phase 1-6) |
| M11 | ⚪ 未开始 | — | — | TBD |
| M12 | ⚪ 未开始 | — | — | TBD |

## 硬约束

项目通过一系列硬约束 (Hard Constraints) 确保质量与安全：

| 约束 | 范围 | 说明 |
|------|------|------|
| **H1** | 架构 | x86_64 only，不支持 ARM64 |
| **H7-H8** | Git | Git 操作安全性与一致性 |
| **H12** | Agent | Agent Authorization — 工具调用需授权 |
| **H13** | Agent | Tool Isolation — 工具运行在隔离环境 |
| **H14** | Agent | Agent Audit — 全量审计日志 |
| **H15-H18** | MCP | MCP/Skills/Rules 运行时安全 |
| **H19-H24** | Compatibility | 兼容层基础设施（Manifest、Contract、Version、Permission） |
| **H25** | Extension | 进程隔离 — Extension Host 崩溃不影响主进程 |
| **H26** | Extension | API Surface Boundary — 未声明 API 不静默 Shim |
| **H27** | Extension | 资源限制 — CPU/内存超限终止 |

## 项目结构

```
AppKCode/
├── Package.swift                    # SPM 包定义（11 targets）
├── Sources/
│   ├── AppKCodeApp/                 # @main 入口点
│   ├── AppKCodePresentation/        # SwiftUI UI 层 (43 files)
│   │   ├── AIChat/                  # AI 聊天界面
│   │   ├── AgentRuntime/            # Agent 运行时 UI
│   │   ├── Git/                     # Git 状态栏
│   │   ├── MCP/                     # MCP 管理界面
│   │   ├── Rules/                   # 规则管理界面
│   │   ├── Skills/                  # 技能管理界面
│   │   ├── AgentChatView.swift
│   │   ├── EditorView.swift
│   │   ├── IDEShellView.swift
│   │   ├── ProjectExplorerView.swift
│   │   ├── TerminalView.swift
│   │   └── ...
│   ├── AppKCodeApplication/         # 应用服务编排 (20 files)
│   │   ├── AIChat/
│   │   ├── AgentRuntime/
│   │   ├── Compatibility/
│   │   ├── MCP/
│   │   ├── Rules/
│   │   ├── Skills/
│   │   ├── AgentOrchestrator.swift
│   │   ├── ApprovalService.swift
│   │   ├── ServiceContainer.swift
│   │   ├── ToolRouter.swift
│   │   └── WorkspaceService.swift
│   ├── AppKCodeDomain/              # 领域模型 (125 files)
│   │   ├── AIChat/                  # AI 聊天模型
│   │   ├── AgentRuntime/            # Agent 运行时模型
│   │   ├── Build/                   # 构建模型
│   │   ├── Compatibility/           # 兼容层（VS Code/JetBrains API Surface）
│   │   ├── Context/                 # 上下文模型
│   │   ├── EditorCore/              # 编辑器核心
│   │   ├── Git/                     # Git 领域
│   │   ├── LanguageService/         # 语言服务
│   │   ├── MCP/                     # MCP 领域
│   │   ├── PluginCapabilities/      # 插件能力
│   │   ├── Rules/                   # 规则引擎
│   │   ├── Skills/                  # 技能系统
│   │   ├── Terminal/                # 终端模型
│   │   └── ...
│   ├── AppKCodeExtensionHost/       # Extension Host 进程管理 (6 files)
│   │   └── Compatibility/
│   │       ├── ExtensionHostProcessManager.swift
│   │       ├── ExtensionHostSupervisor.swift
│   │       ├── ExtensionResourceLimiter.swift
│   │       ├── IPCChannel.swift
│   │       ├── RuntimeDetector.swift
│   │       └── VSCodePackageParser.swift
│   ├── AppKCodeInfrastructure/      # 基础设施 (51 files)
│   │   ├── AIChat/                  # AI 聊天 HTTP 客户端
│   │   ├── AgentRuntime/            # Agent 存储
│   │   ├── Compatibility/           # 兼容层存储
│   │   ├── Git/                     # Git CLI 封装
│   │   ├── LSP/                     # LSP 客户端 + JSON-RPC
│   │   ├── MCP/                     # MCP 传输层
│   │   ├── Rules/                   # 规则加载器
│   │   ├── Skills/                  # 技能加载器
│   │   ├── Terminal/                # 终端缓冲区/渲染
│   │   ├── Toolchain/               # 工具链检测
│   │   ├── PTYManager.swift
│   │   ├── ProcessRunner.swift
│   │   ├── RipgrepClient.swift
│   │   ├── VT100Parser.swift
│   │   └── ...
│   ├── AppKCodeShared/              # 共享类型 (58 files)
│   │   ├── AIChat/
│   │   ├── AgentRuntime/
│   │   ├── Compatibility/           # 兼容层类型（Manifest、Contract、Permission）
│   │   ├── Context/
│   │   ├── Git/
│   │   ├── MCP/
│   │   ├── ModelProvider/
│   │   ├── Rules/
│   │   ├── Skills/
│   │   └── ...
│   ├── AppKCodePluginVSCode/        # VS Code 兼容插件
│   │   └── resources/
│   │       ├── extension-host.js    # Extension Host JS
│   │       ├── vscode-shim.js       # VS Code API Shim
│   │       ├── workspace-fs-shim.js # 文件系统 Shim
│   │       ├── window-commands-shim.js
│   │       ├── base-types-shim.js
│   │       └── languages-extensions-shim.js
│   ├── AppKCodePluginJetBrains/     # JetBrains 兼容插件
│   │   └── resources/
│   │       ├── plugin-host.js       # Plugin Host JS
│   │       ├── openapi-shim.js      # OpenAPI Shim
│   │       └── classloader-isolation.js
│   └── AppKCodePluginNative/        # Native 插件
├── Tests/
│   ├── AppKCodeSharedTests/
│   ├── AppKCodeDomainTests/
│   ├── AppKCodeInfrastructureTests/
│   ├── AppKCodeApplicationTests/
│   ├── AppKCodeExtensionHostTests/
│   ├── AppKCodeIntegrationTests/    # VS Code/JetBrains Contract + Hard Constraint
│   └── AppKCodeContractTests/
├── CI/
│   ├── arch-check.sh
│   ├── arm-dep-check.sh
│   ├── intel-build.yml
│   ├── intel-smoke-test.sh
│   └── release.yml
└── .codeartsdoer/                   # 规格文档与 Gate Evidence
    └── specs/appk_spec_001/
        ├── spec.md                  # 项目规格
        ├── design.md                # 技术设计
        ├── tasks.md                 # 任务计划
        ├── m10_spec.md              # M10 需求规格
        ├── m10_design.md            # M10 实现方案
        ├── m10_tasks.md             # M10 任务计划
        └── ...
```

## 统计

| 指标 | 数值 |
|------|------|
| Swift 源文件 | 373 |
| 源代码行数 | ~25,172 |
| 测试数 | 921 |
| 测试通过率 | 100% |
| SPM Targets | 11 |
| 硬约束 | 27 (H1-H27) |
| VS Code API | 36 |
| JetBrains OpenAPI | 9 接口 / 24 方法 |

## 开发工作流

本项目采用 SPEC → DESIGN → TASK → IMPLEMENTATION 结构化开发流程：

1. **需求规格** (`spec-requirement-agent`)：生成 EARS 格式需求
2. **技术设计** (`spec-design-agent`)：生成架构方案与接口定义
3. **任务规划** (`spec-task-agent`)：分解为可执行的编码任务
4. **编码实现**：逐 Task 实现，每 Task 完成后 Build + Test + Arch Check 全通过

每个里程碑完成后进入 FROZEN 状态，后续里程碑不得修改已冻结的源文件。

## 许可证

本项目暂未指定开源许可证。
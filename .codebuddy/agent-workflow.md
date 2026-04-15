# Agentic Engineering 工作流

> 本项目采用 Agent 驱动的开发模式。以下定义了项目的开发工作流和协作规范。

## 工作流概览

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│  1. Explore  │───▶│  2. Design   │───▶│  3. Build   │───▶│  4. Verify   │
│  探索与学习   │    │  架构与设计   │    │  编码与实现   │    │  测试与验证   │
└─────────────┘    └──────────────┘    └─────────────┘    └──────────────┘
       ▲                                                         │
       └─────────────────── 5. Iterate 迭代优化 ──────────────────┘
```

## Phase 1: Explore（探索与学习）

**目标**：确保开发者理解 AI 基础知识，建立正确的心智模型。

### Agent 任务清单
- [x] 生成科普文档（docs/ 目录）
- [x] 确认开发者理解模型分类（外部 vs 端侧，Dense vs MoE）
- [ ] 梳理 iOS 端可用的 AI 框架和工具

### 关键输出
- `docs/01-ai-basics.md` — AI 基础概念
- `docs/02-model-categories.md` — 模型分类详解
- `docs/03-text-models.md` — 纯文本模型
- `docs/04-moe-models.md` — MoE 模型
- `docs/05-on-device-deployment.md` — 部署指南

## Phase 2: Design（架构与设计）

**目标**：设计可扩展的模型对比架构。

### 核心设计原则
1. **协议驱动** — 所有模型提供者遵循统一协议，方便扩展
2. **可插拔** — 新增模型只需实现协议，无需修改现有代码
3. **可对比** — 内置 Benchmark 能力，量化模型差异

### Agent 任务清单
- [x] 定义 `AIModelProvider` 协议
- [x] 设计统一的对话数据模型
- [x] 设计 Benchmark 指标体系（延迟、吞吐、内存、质量）
- [x] 规划 UI 交互方案

### 关键输出
- `AIInfraApp/Core/Protocols/` — 协议定义
- `AIInfraApp/Core/Models/` — 数据模型

## Phase 3: Build（编码与实现）

**目标**：逐步实现功能，每个阶段可独立运行和验证。

### 实现路线图

#### Step 3.1: 外部模型接入（最简单，建立信心）
```
RemoteProvider/
├── OpenAIProvider.swift        # OpenAI API 接入
├── ClaudeProvider.swift        # Claude API 接入
└── RemoteProviderConfig.swift  # API 配置管理
```

#### Step 3.2: 端侧纯文本模型（核心难点）
```
OnDeviceProvider/
├── CoreMLProvider.swift        # Apple CoreML 方案
├── LlamaCppProvider.swift      # llama.cpp 方案（更灵活）
└── ModelDownloader.swift       # 模型下载管理
```

#### Step 3.3: MoE 模型支持（进阶探索）
```
OnDeviceProvider/
├── MoEProvider.swift           # MoE 模型适配
└── MoEBenchmark.swift          # MoE 专项测试
```

#### Step 3.4: 对比与 Benchmark
```
Features/Benchmark/
├── BenchmarkRunner.swift       # 测试执行器
├── BenchmarkResult.swift       # 结果数据模型
└── BenchmarkView.swift         # 结果展示 UI
```

### Agent 任务清单
- [x] 实现基础 UI 框架（Chat 界面）
- [x] 接入外部模型 API
- [ ] 集成端侧模型运行时               ← 🎯 当前在这里
- [ ] 实现 MoE 模型支持
- [ ] 完成 Benchmark 模块

## Phase 4: Verify（测试与验证）

**目标**：确保功能正确性和性能可接受。

### 验证维度
| 维度 | 指标 | 工具 |
|------|------|------|
| 功能正确性 | 模型输出是否合理 | 人工评估 + 自动化测试 |
| 性能 | 首 Token 延迟、生成速度 | 内置 Benchmark |
| 资源 | 内存占用、CPU/GPU 使用率 | Instruments |
| 稳定性 | 长时间运行不崩溃 | Stress Test |

### Agent 任务清单
- [ ] 编写单元测试
- [ ] 运行 Benchmark 对比
- [ ] 记录和分析结果

## Phase 5: Iterate（迭代优化）

根据验证结果，回到相应阶段进行优化。

---

## Agent 协作规范

### 提问模板
当需要 Agent 帮助开发时，使用以下格式：

```
## 当前阶段：Phase X
## 任务：[具体任务描述]
## 上下文：[相关背景信息]
## 期望输出：[希望 Agent 产出什么]
```

### 代码提交规范
```
feat: 新增功能
fix: 修复问题
docs: 文档更新
refactor: 重构
benchmark: 性能测试相关
```

### 文档更新规则
- 每个新功能必须同步更新对应文档
- Benchmark 结果必须记录在 `docs/` 中
- 踩坑经验必须记录，帮助后来者

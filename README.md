# iOS Client AI Infra

> 探索基于 iOS 端的 AI Infra 能力，专注端模型开发，探索端模型开发过程的能力和边界。

## 项目目标

本项目面向**没有大模型基础的客户端开发者**，通过循序渐进的方式：

1. **科普端侧 AI 基础概念** — 从最简单的概念开始，逐步深入
2. **对比外部模型 vs 端侧模型** — 理解两种模式的差异和适用场景
3. **探索纯文本模型 vs MoE 模型** — 了解不同模型架构的特点
4. **提供可运行的 iOS Demo** — 方便对比不同模型的效果

## 项目架构

```
ios-client-ai-infra/
├── docs/                          # 知识科普文档（循序渐进）
│   ├── 01-ai-basics.md            # AI 基础：什么是大模型
│   ├── 02-model-categories.md     # 模型分类：外部模型 vs 端侧模型
│   ├── 03-text-models.md          # 纯文本模型详解
│   ├── 04-moe-models.md           # MoE 模型详解
│   └── 05-on-device-deployment.md # 端侧部署实践指南
├── AIInfraApp/                    # iOS Demo 工程
│   ├── AIInfraApp.xcodeproj/      # Xcode 工程文件
│   ├── Core/                      # 核心抽象层
│   │   ├── Protocols/             # 协议定义
│   │   ├── Models/                # 数据模型
│   │   └── Utils/                 # 工具类
│   ├── Features/                  # 功能模块
│   │   ├── Chat/                  # 聊天交互界面
│   │   ├── Benchmark/             # 模型性能对比
│   │   └── ModelManager/          # 模型管理
│   ├── Providers/                 # 模型提供者（可插拔）
│   │   ├── RemoteProvider/        # 外部 API 模型（OpenAI、Claude 等）
│   │   └── OnDeviceProvider/      # 端侧模型（CoreML、llama.cpp 等）
│   └── Resources/                 # 资源文件
├── scripts/                       # 辅助脚本
│   └── setup.sh                   # 环境初始化脚本
├── .codebuddy/                    # Agent 工作流配置
│   └── agent-workflow.md          # Agentic Engineering 工作流定义
└── README.md                      # 本文件
```

## 模型分类速览

| 维度 | 分类 | 特点 | 典型代表 |
|------|------|------|----------|
| **部署位置** | 外部模型 | 通过 API 调用，能力强，需网络 | GPT-4、Claude、Gemini |
| | 端侧模型 | 运行在手机上，离线可用，隐私好 | Gemma 2B、Phi-3-mini、Llama 3.2 |
| **架构类型** | 纯文本(Dense) | 所有参数都参与计算，结构简单 | Llama、Gemma |
| | MoE | 混合专家，只激活部分参数，效率高 | Mixtral、DeepSeek-V2 |

## 快速开始

### 1. 阅读文档（推荐顺序）

```
docs/01-ai-basics.md          → 先了解基本概念
docs/02-model-categories.md   → 再理解模型分类
docs/03-text-models.md        → 深入纯文本模型
docs/04-moe-models.md         → 了解 MoE 架构
docs/05-on-device-deployment.md → 动手部署到手机
```

### 2. 运行 Demo

1. 使用 Xcode 16+ 打开 `AIInfraApp/AIInfraApp.xcodeproj`
2. 选择目标设备（推荐真机，iPhone 15 Pro 及以上）
3. 运行项目，在 App 中切换不同模型进行对比

### 3. Agent 工作流

本项目使用 Agentic Engineering 方式开发，详见 `.codebuddy/agent-workflow.md`。

## 系统要求

- Xcode 16.0+
- iOS 17.0+
- Swift 5.9+
- 真机测试推荐：iPhone 15 Pro 及以上（A17 Pro 芯片，支持更大模型）

## License

MIT

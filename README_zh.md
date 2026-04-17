# iOS 端侧 AI 基础设施

**[English](README.md)**

面向 iOS 开发者的端侧大模型教学应用。基于 SwiftUI 和 llama.cpp 构建，帮助开发者理解、部署和评测端侧 AI 模型，无需 AI/ML 背景知识。

## 功能特性

- **端侧大模型对话** -- 模型完全运行在 iPhone 本地，支持 Qwen、Llama、Gemma 4、Phi、SmolLM 等模型家族
- **模型下载商店** -- App 内直接浏览、下载、管理 GGUF 模型文件。支持国内镜像源（hf-mirror.com），中国大陆可直连下载
- **性能测评** -- 12 个客户端场景标准测试用例，自动质量评分，多模型横向对比速度、延迟、内存和输出质量
- **学习中心** -- 9 章交互式教程，覆盖 Transformer 架构、量化技术、采样策略、llama.cpp 集成、性能优化等。所有内容支持 Markdown 渲染和 LaTeX 数学公式
- **Markdown 渲染** -- 模型回复和学习内容使用 Textual 库渲染，支持代码语法高亮、表格和 LaTeX 公式
- **对话历史** -- 自动保存对话记录，可恢复历史对话，方便对比不同模型对相同问题的回答
- **双语支持** -- 完整的中英文界面，App 内一键切换语言

## 支持的模型

| 模型 | 参数量 | 量化 | 文件大小 | 特点 |
|------|-------|------|---------|------|
| Qwen2.5 0.5B | 0.5B | Q4_K_M | ~400 MB | 超轻量，中文可用 |
| Qwen2.5 1.5B | 1.5B | Q4_K_M | ~1 GB | 同级别中文最好 |
| Qwen2.5 3B | 3B | Q4_K_M | ~2 GB | 中文理解能力强 |
| Llama 3.2 1B | 1B | Q4_K_M | ~750 MB | 英文好，轻量 |
| Llama 3.2 3B | 3B | Q4_K_M | ~2 GB | 综合均衡 |
| Gemma 2 2B | 2B | Q4_K_M | ~1.6 GB | 训练数据质量高 |
| Gemma 4 E2B | 2.3B | Q4_K_M | ~3.1 GB | 内置思考链推理 |
| Phi-3.5 Mini | 3.8B | Q4_K_M | ~2.3 GB | 推理和代码能力强 |
| SmolLM2 360M | 360M | Q8_0 | ~386 MB | 几乎所有 iPhone 都能跑 |

## 系统要求

- **iOS 18.0+**
- **Xcode 16.0+**（Swift 5.9+）
- **推荐设备**：iPhone 15 Pro 及以上（8GB RAM，A17 Pro 芯片）
- 轻量模型（0.5-1B）最低要求：iPhone 13 及以上

## 快速开始

1. **克隆仓库**

   ```bash
   git clone https://github.com/user/ios-client-ai-infra.git
   cd ios-client-ai-infra
   ```

2. **打开 Xcode 工程**

   ```
   open AIInfraApp/AIInfraApp/AIInfraApp.xcodeproj
   ```

3. **编译运行**（推荐连接真机）

4. **下载模型** -- 进入「模型」Tab → 模型商店 → 选择一个模型下载。首次推荐 Qwen2.5 0.5B。

5. **开始对话** -- 切换到「对话」Tab，选择已下载的模型，开始聊天。

## 项目架构

```
AIInfraApp/
├── Core/
│   ├── Protocols/
│   │   └── AIModelProvider.swift       # 统一 Provider 协议
│   ├── Models/
│   │   ├── ChatModels.swift            # 对话消息、会话、配置
│   │   └── BenchmarkModels.swift       # 测试用例、质量评分规则
│   └── Utils/
│       ├── LanguageManager.swift       # App 内语言切换
│       ├── L10n.swift                  # 国际化 UI 字符串
│       ├── ChatHistoryStore.swift      # JSON 对话持久化
│       ├── APIKeyStore.swift           # 下载镜像源设置
│       └── DeviceUtils.swift           # 内存、热状态监控
├── Features/
│   ├── Chat/ChatView.swift             # 聊天界面（Markdown 渲染）
│   ├── Benchmark/BenchmarkView.swift   # 测评界面（质量评分）
│   ├── ModelManager/                   # 模型列表、下载商店
│   └── Learn/                          # 9 章学习中心
├── Providers/
│   └── OnDeviceProvider/
│       ├── LlamaEngine.swift           # llama.cpp Swift 桥接层
│       ├── LlamaOnDeviceProvider.swift # 端侧推理 Provider 实现
│       ├── GGUFModelCatalog.swift      # 模型下载目录
│       └── ModelDownloadManager.swift  # 下载/暂停/恢复管理
└── LocalPackages/
    └── LlamaFramework/                # llama.cpp xcframework (SPM 二进制)
```

### 关键设计

- **协议驱动架构**：所有模型提供者遵循 `AIModelProvider` 协议，方便扩展新模型后端
- **llama.cpp SPM 二进制集成**：预编译 xcframework，无需本地编译 C++ 代码。默认启用 Metal GPU 加速
- **UTF-8 流式解码**：自定义 `UTF8StreamDecoder` 处理 token 边界处的多字节字符，防止中文和 Emoji 乱码
- **自动 Chat Template**：`detectModelFamily()` 根据模型文件名自动检测模型家族，应用正确的 prompt 格式

## 测评质量评分

测评系统包含自动质量评估，使用 8 种规则类型：

| 规则类型 | 说明 |
|---------|------|
| `containsAny` | 输出包含预期关键词之一 |
| `containsAll` | 输出包含所有预期关键词 |
| `notContains` | 输出不包含禁止词 |
| `validJSON` | 输出为合法 JSON 且含必要字段 |
| `matchesRegex` | 输出匹配正则表达式 |
| `lengthRange` | 输出长度在预期范围内 |
| `exactAnswer` | 输出包含正确答案 |
| `containsCodeBlock` | 输出包含代码内容 |

每个测试用例配置加权评分规则，结果显示为 通过(>=80分) / 部分通过(40-79分) / 未通过(<40分)。

## License

MIT

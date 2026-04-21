# iOS 端侧 AI 基础设施

**[English](README_en.md)**

面向 iOS 开发者的端侧大模型教学应用。基于 SwiftUI 和 llama.cpp 构建，帮助开发者理解、部署和评测端侧 AI 模型，无需 AI/ML 背景知识。

## 功能特性

- **端侧大模型对话** -- 模型完全运行在 iPhone 本地，支持 Qwen、Llama、Gemma 4、Phi、SmolLM 等模型家族
- **多模态图片识别** -- 支持直接发送图片给模型，通过 llama.cpp mtmd 实现端侧图片理解和分类
- **模型下载商店** -- App 内直接浏览、下载、管理 GGUF 模型文件。支持国内镜像源（hf-mirror.com），中国大陆可直连下载
- **性能测评** -- 12 个客户端场景标准测试用例 + 500 条图片分类测试，自动质量评分，多模型横向对比
- **真实图片分类测试** -- 从 CIFAR-10 数据集下载 500 张测试图片到本地，测试多模态模型的图片识别准确率和速度
- **学习中心** -- 10 章交互式教程，覆盖 Transformer 架构、量化技术、采样策略、llama.cpp 集成、性能优化、MoE 图片分类等
- **Markdown 渲染** -- 模型回复和学习内容使用 Textual 库渲染，支持代码语法高亮、表格和 LaTeX 公式
- **对话历史** -- 自动保存对话记录，可恢复历史对话
- **双语支持** -- 完整的中英文界面，App 内一键切换语言

## 支持的模型

### 文本模型

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

### 多模态视觉模型（支持图片输入）

| 模型 | 参数量 | 模型大小 | mmproj 大小 | 特点 |
|------|-------|---------|------------|------|
| SmolVLM 500M | 500M | 437 MB | 109 MB | 超轻量多模态，iPhone 13+ |
| InternVL3 1B | 1B | 675 MB | 333 MB | 中英文图片理解 |
| Qwen2-VL 2B | 2B | 986 MB | 710 MB | 中文图片分类最佳 |
| Qwen2.5-VL 3B | 3B | 1.93 GB | 845 MB | 中文最强视觉模型 |
| Gemma 4 E2B Vision | 2.3B | 3.11 GB | 557 MB | 多语言，需 iPhone 15 Pro |

> 多模态模型需要下载两个文件：主模型 + mmproj（视觉编码器）。App 内下载时会自动同时下载。

## 系统要求

- **iOS 17.0+**
- **Xcode 15.0+**（Swift 5.10+）
- **推荐设备**：iPhone 15 Pro 及以上（8GB RAM，A17 Pro 芯片）
- 轻量模型（0.5-1B）最低要求：iPhone 13 及以上

## 快速开始

1. **克隆仓库**

   ```bash
   git clone https://github.com/JellyP/ios-client-ai-infra.git
   cd ios-client-ai-infra
   ```

2. **打开 Xcode 工程**

   ```
   open AIInfraApp/AIInfraApp/AIInfraApp.xcodeproj
   ```

3. **编译运行**（推荐连接真机）

4. **下载模型** -- 进入「模型」Tab → 模型商店 → 选择一个模型下载。首次推荐 Qwen2.5 0.5B。

5. **开始对话** -- 切换到「对话」Tab，选择已下载的模型，开始聊天。

6. **图片识别（可选）** -- 下载一个 Vision 模型（如 Qwen2-VL 2B），在对话页点击 📷 选择图片发送给模型。

## 多模态图片识别

本项目集成了 llama.cpp 的 mtmd（多模态）库，支持端侧图片输入：

```
UIImage → JPEG Data → mtmd_helper_bitmap_init_from_buf()
    → mtmd_tokenize() → mtmd_helper_eval_chunks()
    → llama_decode() → 文本输出
```

### 自编译 xcframework

项目默认使用含 mtmd 多模态支持的自编译 xcframework（托管在 GitHub Release）。如需重新编译：

```bash
./scripts/build-llama-xcframework.sh
```

编译产物会输出到 `LocalPackages/LlamaFramework/llama.xcframework`。

## 项目架构

```
AIInfraApp/
├── Core/
│   ├── Protocols/
│   │   └── AIModelProvider.swift       # 统一 Provider 协议
│   ├── Models/
│   │   ├── ChatModels.swift            # 对话消息（支持图片）
│   │   ├── BenchmarkModels.swift       # 测试用例、质量评分规则
│   │   ├── ImageClassification*.swift  # 图片分类测试套件（500条中英文）
│   │   └── ImageClassificationReal*.swift # 真实图片测试套件
│   └── Utils/
│       ├── L10n.swift                  # 国际化 UI 字符串
│       ├── ImageDatasetManager.swift   # CIFAR-10 图片数据集下载
│       └── ...
├── Features/
│   ├── Chat/ChatView.swift             # 聊天界面（支持图片发送）
│   ├── Benchmark/BenchmarkView.swift   # 测评（文本分类+真实图片分类）
│   ├── ModelManager/                   # 模型列表、下载商店（含 mmproj）
│   └── Learn/                          # 10 章学习中心
├── Providers/
│   └── OnDeviceProvider/
│       ├── LlamaEngine.swift           # llama.cpp + mtmd 桥接层
│       ├── LlamaOnDeviceProvider.swift # 端侧推理（文本+多模态路由）
│       ├── GGUFModelCatalog.swift      # 模型目录（含 Vision 模型）
│       └── ModelDownloadManager.swift  # 下载管理（支持 mmproj）
├── LocalPackages/
│   └── LlamaFramework/                # llama.cpp xcframework (含 mtmd)
├── docs/                              # 技术文档
│   └── 06-moe-image-classification.md # MoE 图片分类完整指南
└── scripts/
    └── build-llama-xcframework.sh     # xcframework 编译脚本
```

## 技术文档

| 文档 | 内容 |
|------|------|
| [01-AI 基础](docs/01-ai-basics.md) | AI 基础概念 |
| [02-模型分类](docs/02-model-categories.md) | 模型分类和选型 |
| [03-文本模型](docs/03-text-models.md) | 文本模型详解 |
| [04-MoE 模型](docs/04-moe-models.md) | MoE 架构详解 |
| [05-端侧部署](docs/05-on-device-deployment.md) | 端侧部署实践 |
| [06-MoE 图片分类](docs/06-moe-image-classification.md) | MoE 图片识别完整指南（Apple Vision vs MoE 对比） |

## License

MIT

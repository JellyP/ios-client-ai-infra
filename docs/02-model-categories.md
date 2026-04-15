# 02 - 模型分类：外部模型 vs 端侧模型

> 理解两种模型部署方式的本质差异，帮助你选择合适的方案。

## 核心对比

```
┌──────────────────────────────────────────────────────────────────┐
│                        外部模型 (Remote)                         │
│                                                                  │
│  iPhone ──── Internet ────▶ Cloud Server ────▶ 超大模型推理       │
│    App         网络请求        API 服务          GPT-4 等         │
│                                                                  │
│  ✅ 能力强  ✅ 无设备限制  ❌ 需要网络  ❌ 有成本  ❌ 隐私风险     │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                        端侧模型 (On-Device)                      │
│                                                                  │
│  iPhone ────▶ 本地模型推理 ────▶ 结果                             │
│    App         NPU/GPU/CPU       直接输出                        │
│                                                                  │
│  ✅ 离线可用  ✅ 隐私安全  ✅ 低延迟  ❌ 能力有限  ❌ 占用存储     │
└──────────────────────────────────────────────────────────────────┘
```

## 详细对比表

| 维度 | 外部模型 | 端侧模型 |
|------|----------|----------|
| **网络依赖** | 必须联网 | 完全离线 |
| **模型大小** | 不受限（云端运行） | 受限于设备内存（1-7B） |
| **推理速度** | 取决于网络 + 服务器负载 | 取决于设备算力 |
| **首字延迟** | 200ms - 2s（含网络） | 50ms - 500ms（纯本地） |
| **隐私** | 数据发送到服务器 | 数据不出设备 |
| **成本** | 按 token 付费 | 免费（模型开源） |
| **能力** | 非常强（GPT-4 级别） | 有限（简单任务为主） |
| **维护** | API 提供商维护 | 需自行管理模型文件 |

## 外部模型接入指南

### 对 iOS 开发者来说很简单

外部模型就是**调 API**，和你平时调后端接口没有本质区别：

```swift
// 伪代码示意 - 外部模型调用
func callRemoteModel(prompt: String) async throws -> String {
    let request = URLRequest(url: apiEndpoint)
    request.httpBody = try JSONEncoder().encode([
        "model": "gpt-4",
        "messages": [["role": "user", "content": prompt]]
    ])
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(ChatResponse.self, from: data)
    return response.choices.first?.message.content ?? ""
}
```

### 主流外部模型 API

| 提供商 | 模型 | 特点 | 价格参考 |
|--------|------|------|----------|
| OpenAI | GPT-4o | 综合能力最强 | $2.5/1M input tokens |
| Anthropic | Claude 3.5 | 代码能力优秀 | $3/1M input tokens |
| Google | Gemini 1.5 | 超长上下文 | 有免费额度 |
| DeepSeek | DeepSeek-V3 | 性价比高 | ¥1/1M tokens |

### 流式响应（SSE）

大模型 API 通常支持流式输出，这是实现"打字机效果"的关键：

```swift
// 伪代码示意 - 流式响应
func streamRemoteModel(prompt: String) -> AsyncStream<String> {
    AsyncStream { continuation in
        // 通过 SSE (Server-Sent Events) 逐步接收 token
        // 每收到一个 token 就通过 continuation.yield() 发送
        // UI 层监听这个 stream 实时更新显示
    }
}
```

## 端侧模型部署指南

### iOS 上运行模型的三种方式

```
方式 1: Apple CoreML
┌──────────┐    ┌──────────┐    ┌──────────┐
│ 原始模型  │───▶│ 转换工具  │───▶│ .mlmodel │───▶ CoreML Framework
│ (PyTorch) │    │coremltools│    │ .mlpackage│
└──────────┘    └──────────┘    └──────────┘
优点: Apple 原生，性能优化好，自动利用 NPU
缺点: 转换复杂，模型支持有限

方式 2: llama.cpp (推荐入门)
┌──────────┐    ┌──────────┐    ┌──────────┐
│ 原始模型  │───▶│ 量化转换  │───▶│ .gguf    │───▶ llama.cpp C++ 库
│ (HuggingFace)│ │          │    │ 格式文件  │
└──────────┘    └──────────┘    └──────────┘
优点: 支持模型多，社区活跃，量化方案成熟
缺点: 需要 C++ 桥接，不能利用 NPU

方式 3: MLX (Apple Silicon 优化)
┌──────────┐    ┌──────────┐    ┌──────────┐
│ 原始模型  │───▶│ MLX转换   │───▶│ MLX格式  │───▶ MLX Swift 库
│ (HuggingFace)│ │          │    │          │
└──────────┘    └──────────┘    └──────────┘
优点: Apple Silicon 深度优化，Swift 原生
缺点: 较新，iOS 支持还在发展中
```

### 推荐的端侧模型

| 模型 | 参数量 | 量化后大小 | 适合设备 | 特点 |
|------|--------|-----------|----------|------|
| Gemma 2 2B | 2B | ~1.5GB (Q4) | iPhone 15+ | Google 出品，中英文不错 |
| Phi-3-mini | 3.8B | ~2.2GB (Q4) | iPhone 15 Pro+ | 微软出品，推理能力强 |
| Llama 3.2 1B | 1B | ~0.7GB (Q4) | iPhone 13+ | Meta 出品，最轻量 |
| Llama 3.2 3B | 3B | ~1.8GB (Q4) | iPhone 15 Pro+ | Meta 出品，均衡 |
| Qwen2.5-1.5B | 1.5B | ~1GB (Q4) | iPhone 14+ | 阿里出品，中文最好 |

> **Q4 量化**：将模型参数从 FP16（16位浮点）压缩到 INT4（4位整数），
> 体积缩小约 4 倍，精度略有损失但可接受。

## 实际开发中怎么选？

### 决策流程

```
需求来了
    │
    ▼
需要强推理能力？ ──是──▶ 用外部模型
    │
    否
    ▼
需要离线使用？ ──是──▶ 用端侧模型
    │
    否
    ▼
对隐私有要求？ ──是──▶ 用端侧模型
    │
    否
    ▼
预算有限？ ──是──▶ 用端侧模型（免费）
    │
    否
    ▼
用外部模型（效果更好）
```

### 混合方案（推荐）

```
简单任务（文本补全、分类、摘要）→ 端侧模型
复杂任务（长文写作、代码生成）  → 外部模型
无网络时                       → 端侧模型兜底
```

## 下一步

了解了两种部署方式后，我们深入看看 → [03 - 纯文本模型详解](03-text-models.md)

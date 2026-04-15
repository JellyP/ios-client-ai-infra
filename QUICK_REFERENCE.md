# 工程快速参考指南

## 核心文件地图

### 🎯 立即查看这些文件来理解乱码问题

```
关键推理文件:
├── AIInfraApp/AIInfraApp/AIInfraApp/Providers/OnDeviceProvider/
│   ├── LlamaEngine.swift                 ← ⭐️ 最关键，UTF-8 处理在这里
│   └── LlamaCppProvider.swift            ← 对接协议
├── AIInfraApp/Providers/OnDeviceProvider/
│   ├── GGUFModelCatalog.swift            ← 模型列表
│   └── ModelDownloadManager.swift        ← 模型下载
└── AIInfraApp/Providers/RemoteProvider/
    └── OpenAICompatibleProvider.swift    ← Ollama 集成在这里
```

---

## 关键代码位置速查表

| 功能 | 文件 | 行数 | 问题 |
|------|------|------|------|
| **CChar → UInt8 转换** | `LlamaEngine.swift` | 343-352 | 位转换可能有问题 |
| **UTF-8 缓冲处理** | `LlamaEngine.swift` | 181-191 | ⚠️ 多字节字符在 token 边界断裂 |
| **残留字节处理** | `LlamaEngine.swift` | 202-207 | 无效 UTF-8 被丢弃 |
| **Chat Template** | `LlamaEngine.swift` | 214-286 | Gemma 4 手动格式构造 |
| **流式响应解析** | `OpenAICompatibleProvider.swift` | 211-274 | SSE 格式解析 |
| **UI 更新** | `ChatView.swift` | 365-371 | token 流显示 |

---

## 工程类型概览

### 项目属性
- **语言**: Swift 5.9+
- **框架**: SwiftUI
- **最低版本**: iOS 17.0+
- **包管理**: SPM (Swift Package Manager)
- **CI**: 使用 Xcode 16+

### 支持的模型
- **端侧**: Qwen, Llama, Gemma, Phi, SmolLM (通过 llama.cpp)
- **远程**: OpenAI, DeepSeek, Ollama, vLLM (通过 OpenAI 兼容 API)

---

## llama.cpp 集成详情

### SPM 配置
```swift
// 二进制框架从这里下载:
url: "https://github.com/ggml-org/llama.cpp/releases/download/b8783/llama-b8783-xcframework.zip"
// 文件: AIInfraApp/AIInfraApp/LocalPackages/LlamaFramework/Package.swift
```

### 核心 C API 调用
```swift
// 模型加载
llama_model_load_from_file()      ← 返回 OpaquePointer
llama_new_context_with_model()    ← 返回 OpaquePointer

// Token 生成
llama_sampler_sample()            ← 返回 llama_token (Int32)
llama_token_to_piece()            ← 转为 C 字符串

// Tokenize
llama_tokenize()                  ← 文本 → token 数组

// Chat
llama_chat_apply_template()       ← 应用 chat template
```

---

## Ollama 如何集成

**方式**: 不直接集成，而是通过 OpenAI 兼容 API

**配置**:
```swift
let config = RemoteAPIConfig.custom(
    baseURL: "http://localhost:11434/v1",  // Ollama 服务地址
    apiKey: "",                             // Ollama 不需要 API Key
    model: "llama2"                         // 选择的模型
)
```

**流程**:
```
Ollama (本地运行) 
  ↓
OpenAI 兼容 API 端点 (/v1/chat/completions)
  ↓
OpenAICompatibleProvider.swift 的 SSE 流式处理
  ↓
UI 显示
```

---

## 乱码问题根源

### 概率最高的原因
**UTF-8 多字节字符在 token 边界断裂** (70% 概率)

**症状**:
- 中文输出显示为 ?, ?, ? 或乱码
- Emoji 显示异常
- 某些特殊字符显示错误

**发生位置**: `LlamaEngine.swift` 第 181-191 行

### 其他可能的原因
1. CChar 位转换问题 (15%)
2. 残留字节处理 (10%)
3. Chat Template 格式错误 (5%)

---

## 快速定位乱码

### 步骤 1: 确认问题类型
```swift
// 在 LlamaEngine.swift 的 onToken 回调中添加日志
onToken: { tokenText in
    let bytes = [UInt8](tokenText.utf8)
    print("[DEBUG] Token: \(tokenText) | Bytes: \(bytes.map { String(format: "%02X", $0) })")
}
```

### 步骤 2: 检查 token 边界
```
输出示例:
Token: 你 | Bytes: [E4]
Token: (nothing) | Bytes: [BD, A0]
// ↑ 说明在 token 边界被断裂了
```

### 步骤 3: 修复方案
- 使用 `UTF8StreamDecoder` 类
- 参考: `ENCODING_ISSUES_ANALYSIS.md` 第 2 节

---

## 文件修改清单

如果要修复乱码，需要修改这些文件:

```
优先级 1 (必做):
- [ ] AIInfraApp/AIInfraApp/AIInfraApp/Providers/OnDeviceProvider/LlamaEngine.swift
      添加 UTF8StreamDecoder 类
      修改 tokenToBytes() 方法
      修改 generate() 的 decode 循环

优先级 2 (推荐):
- [ ] AIInfraApp/AIInfraApp/AIInfraApp/Providers/OnDeviceProvider/LlamaEngine.swift
      改进 Chat Template 处理 (第 214-286 行)

优先级 3 (可选):
- [ ] 添加单元测试验证 UTF-8 处理
- [ ] 添加集成测试验证中文输出
```

---

## 重要数据结构

### AIModelProvider 协议
```swift
protocol AIModelProvider {
    func chat(messages: [ChatMessage], config: GenerationConfig) 
        -> AsyncThrowingStream<StreamToken, Error>
}

// 所有模型提供者都必须实现这个
// StreamToken 包含: text (String), isFinished (Bool), metrics (GenerationMetrics?)
```

### StreamToken
```swift
struct StreamToken {
    let text: String              // ← 这是最终用户看到的文本
    let isFinished: Bool
    let metrics: GenerationMetrics?
}

// 在 ChatView.swift 中:
continuation.yield(StreamToken(text: tokenText, isFinished: false, metrics: nil))
```

---

## 性能指标

当前工程已经支持性能监控:

```swift
struct GenerationMetrics {
    let prefillTime: TimeInterval           // Prefill 阶段耗时
    let decodeTokensPerSecond: Double       // 生成速度 (重要指标)
    let timeToFirstToken: TimeInterval      // 首字延迟
    let totalGeneratedTokens: Int
    let totalTime: TimeInterval
    let peakMemoryUsage: UInt64
}

// 在 ChatView.swift 中显示这些指标
```

---

## 本地测试

### 端侧模型测试
```swift
// 1. 下载一个小模型 (SmolLM2 360M, ~380MB)
// 2. 在 ModelManager 中选择
// 3. 聊天时查看是否有乱码

// 特别测试:
- "你好" → 应该显示中文
- "👋 Hi" → Emoji 应该正常
- "C++ & Python" → 特殊字符应该正常
```

### 远程模型测试 (本地 Ollama)
```bash
# 启动 Ollama
ollama serve

# 另一个终端拉取模型
ollama pull llama2

# 在 App 中配置:
- Base URL: http://localhost:11434/v1
- Model: llama2
```

---

## 文档导航

1. **快速了解**: 本文件 (3 分钟)
2. **深度分析**: `ENCODING_ISSUES_ANALYSIS.md` (20 分钟)
3. **全面结构**: `PROJECT_STRUCTURE_ANALYSIS.md` (30 分钟)
4. **代码实现**: 查看实际源文件

---

## 关键联系点

### 推理链路
```
ChatView.swift 
  ↓ (调用 provider.chat())
LlamaCppProvider.swift 或 OpenAICompatibleProvider.swift
  ↓ (实现 AIModelProvider 协议)
LlamaEngine.swift (端侧) 或 URLSession (远程)
  ↓ (生成 tokens)
回调 onToken()
  ↓ (解析成字符)
ChatView.swift (更新 UI)
```

### 数据流
```
ChatMessage[]
  ↓ (角色和内容)
generate(messages:, config:)
  ↓ (生成逐个 token)
StreamToken (text, isFinished, metrics)
  ↓ (逐步显示)
UI 更新
```

---

## 常见问题速答

**Q: Ollama 怎么用?**
A: 通过 OpenAI 兼容 API，不需要特殊集成

**Q: 中文乱码怎么办?**
A: 查看 `ENCODING_ISSUES_ANALYSIS.md` 第 2 节，实现 UTF8StreamDecoder

**Q: 支持什么模型?**
A: 查看 `GGUFModelCatalog.swift`，列出了所有支持的模型

**Q: 怎么添加新的远程模型?**
A: 继承 `AIModelProvider` 协议，参考 `OpenAICompatibleProvider.swift`

**Q: 性能不够快怎么办?**
A: 选择小一点的模型，或使用更强的设备 (A17 Pro+)


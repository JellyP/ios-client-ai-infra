# 02 - 云端 vs 端侧：两种部署方式的深度对比

> 这一篇搞清楚：什么时候应该走 API 调云端大模型？什么时候应该把模型装进 iPhone？延迟、成本、隐私、体验，每一项都给你拆到原子级别。

## 读这篇你能收获什么

- 理解云端 API 调用背后的**完整链路**（不只是 URLSession）
- 看清端侧推理的**真实延迟组成**（为什么号称快但实际可能慢）
- 掌握 OpenAI 兼容协议的**流式协议细节**（SSE 协议）
- 学会如何**设计混合架构**（云端 + 端侧互为兜底）
- 知道每种方案的**真实成本**（不只是钱）

---

## 一、核心差异：从请求流开始看

### 云端模型的完整请求流

```
iPhone App                   运营商网络              云服务商
    │                          │                       │
    │ 1. 用户输入               │                       │
    │───▶ URLSession.data(for:) │                       │
    │    (HTTPS 握手 ~50ms)     │                       │
    │                          │                       │
    │ 2. TCP/TLS 建联           │                       │
    │──────────────────────────▶                       │
    │    (RTT 30-200ms)         │                       │
    │                          │                       │
    │ 3. 发送 prompt            │                       │
    │──────────────────────────▶───────────────────────▶
    │                          │                       │
    │                          │              4. 服务器排队
    │                          │              (0-500ms)
    │                          │                       │
    │                          │              5. Prefill
    │                          │              (100-500ms)
    │                          │                       │
    │                          │              6. Decode
    │                          │              (生成 token)
    │                          │                       │
    │ 7. 流式接收 SSE           │                       │
    ◀──────────────────────────◀───────────────────────
    │    data: {"text":"你"}     │                       │
    │    data: {"text":"好"}     │                       │
    │    ...                    │                       │
    │                          │                       │
    │ 8. UI 渲染 token          │                       │
    │                          │                       │

总耗时: 300ms - 3s
  └─ 网络层: 100-500ms (RTT + 连接)
  └─ 服务端: 200-2500ms (排队 + Prefill + Decode)
```

### 端侧模型的完整请求流

```
iPhone App
    │
    │ 1. 用户输入
    │
    │ 2. Tokenize (在主进程内)
    │    字符串 → token 数组
    │    (<1ms)
    │
    │ 3. 喂给 llama.cpp
    │
    │ 4. Prefill (GPU 并行)
    │    100 tokens 处理需 200-800ms
    │
    │ 5. Decode 循环
    │    每个 token 30-100ms
    │    直到遇到 EOS
    │
    │ 6. 流式回调 UI
    │    (通过 AsyncStream)
    │

总耗时: 500ms - 10s
  └─ 加载模型: 3-10s (只发生一次，后续推理不重复)
  └─ Prefill: 200-800ms (决定 TTFT)
  └─ Decode: 每秒 10-50 tokens
```

### 关键认知：端侧不一定比云端快

很多同学以为"没网络所以端侧快"，其实：

```
短 prompt 场景 (20 tokens):
  云端: 网络 100ms + Prefill 50ms + 首 token = 约 150-300ms ✅
  端侧: Prefill 300ms + 首 token = 约 300-500ms

长 prompt 场景 (1000 tokens):
  云端: 网络 100ms + 服务器强力 GPU Prefill 200ms = 约 300ms
  端侧: iPhone Prefill 2-3s = 约 2-3s ❌ 慢很多

生成长度场景 (500 tokens 输出):
  云端: 30 tokens/s，生成完需要 17s
  端侧: 20 tokens/s，生成完需要 25s

结论:
  - 短输入 + 短输出：端侧可能更快
  - 长输入 或 长输出：云端通常更快（因为服务器 GPU 吊打手机）
  - 端侧真正的优势是"没有网络不确定性"，而不是速度
```

---

## 二、云端 API 接入：协议层深度剖析

大模型 API 几乎都**兼容 OpenAI 协议**，所以学会一套就会所有。

### 2.1 基础请求格式

```swift
// 标准的 Chat Completion 请求
struct ChatRequest: Codable {
    let model: String              // "gpt-4o" / "claude-3-5-sonnet" / ...
    let messages: [Message]        // 历史对话
    let stream: Bool               // 是否流式返回
    let temperature: Float?        // 0.0-2.0，默认 1.0
    let topP: Float?              // 0.0-1.0，默认 1.0
    let maxTokens: Int?            // 限制输出长度
    let stop: [String]?            // 停止词
    let frequencyPenalty: Float?   // 抑制重复，-2.0 到 2.0
    let presencePenalty: Float?    // 鼓励新话题，-2.0 到 2.0
}

struct Message: Codable {
    let role: String    // "system" / "user" / "assistant"
    let content: String
}
```

### 2.2 停止机制：模型怎么知道什么时候该"闭嘴"？

上面请求体里有个 `stop: [String]?` 参数，这个参数其实是客户端同学最容易误解的。在展开讲之前，先搞清楚一件事：

**大模型生成的停止，有两种完全不同的机制。**

```
┌────────────────────────────────────────────────────────────┐
│  第 1 种: 模型自主停止                                      │
│  ──────────────────                                        │
│  模型生成了一个特殊 token（EOS Token）                     │
│    Qwen2.5:   <|im_end|>        (token id: 151645)          │
│    Llama 3:   <|eot_id|>        (token id: 128009)          │
│    Gemma:     <end_of_turn>                                 │
│    GPT:       <|endoftext|>                                 │
│                                                             │
│  谁决定？ 模型自己（训练时学会的）                          │
│  finish_reason: "stop"                                      │
└────────────────────────────────────────────────────────────┘
                            VS
┌────────────────────────────────────────────────────────────┐
│  第 2 种: 客户端强制停止（stop 参数）                       │
│  ──────────────────────────                                │
│  你在 API 请求里传 stop: ["User:", "\n\n"]                 │
│  推理引擎边生成边检测字符串，命中就停                       │
│                                                             │
│  谁决定？ 你（客户端）                                     │
│  finish_reason: "stop"                                      │
└────────────────────────────────────────────────────────────┘
```

**关键结论**：`stop` 参数是**客户端决定**的，不是模型自己决定的。模型自己的"自然结束"是靠 EOS token，你不用管。

#### EOS Token：模型"学会"的停止

模型怎么知道什么时候该停？训练时每条数据都有结束标记：

```
训练样本（对话格式）:
  <|im_start|>user
  你好<|im_end|>
  <|im_start|>assistant
  你好！有什么可以帮你？<|im_end|>
                       ↑
                每次 assistant 回答完毕都有这个

模型在看了几百万条这样的样本后学会:
  "当我说完了想说的，就应该输出 <|im_end|>"
```

推理引擎检测到 EOS token 就终止生成，返回给客户端：

```swift
// llama.cpp 里的写法
while true {
    let nextToken = sample(logits)
    if nextToken == llama_vocab_eos(model) {
        break  // 模型说自己讲完了
    }
    output += detokenize(nextToken)
}
```

**这种停止不需要客户端做任何配置，是大模型的默认行为。**

#### stop 参数：你强制指定的"遇到就停"

那 `stop` 参数用来做什么？用来解决**你不想等模型自然结束**的场景。

典型用法：

```swift
// 场景 1: Few-shot prompting（给几个例子让模型仿照）
let prompt = """
分类以下句子：

句子: 今天天气真好
类别: 天气

句子: 我想吃饭
类别: 饮食

句子: 明天下雨吗
类别:
"""

let request = ChatRequest(
    messages: [Message(role: "user", content: prompt)],
    stop: ["\n"]   // 遇到换行就停，只要一行答案
)
// 模型输出: "天气" → 遇到 \n → 停


// 场景 2: 角色对话模拟
stop: ["User:", "Human:", "Question:"]
// 防止模型一口气扮演两个角色自问自答


// 场景 3: JSON 输出
stop: ["}\n"]
// JSON 结束就停，避免模型继续啰嗦


// 场景 4: 代码补全
stop: ["\n\n", "```"]
// 只要当前这一段代码
```

#### 工作原理

```
模型吐 token 流: "你" → "好" → "！" → ...
                               ↓
                    推理引擎累积已输出的字符串
                    检查末尾是否匹配 stop 列表里任何一项
                               ↓
                        匹配 → 立即停止
                        不匹配 → 继续生成
```

Swift 实现：

```swift
class StopSequenceChecker {
    let stopSequences: [String]
    var accumulated = ""
    
    func check(newToken: String) -> Bool {
        accumulated += newToken
        
        // 检查累积字符串末尾是否匹配任何 stop 序列
        for stop in stopSequences {
            if accumulated.hasSuffix(stop) {
                return true  // 命中，停止
            }
        }
        return false
    }
}

// 使用
let checker = StopSequenceChecker(stopSequences: ["User:", "\n\n"])
for try await token in llmStream {
    output += token
    if checker.check(newToken: token) {
        break
    }
}
```

#### finish_reason：告诉你为什么停了

OpenAI 协议响应里有 `finish_reason` 字段，表示本次停止的原因：

| `finish_reason` | 谁决定 | 含义 |
|---|---|---|
| `"stop"` | 模型 或 客户端 | 自然结束（EOS）或匹配到 stop 序列 |
| `"length"` | 客户端 | 达到 max_tokens 限制 |
| `"content_filter"` | 服务商 | 触发内容安全策略 |
| `"tool_calls"` | 模型 | 模型决定调用工具 |
| `null` | - | 流式中间块，还没结束 |

**坑**：`"stop"` 不区分是 EOS 还是 stop 参数命中，都是 `"stop"`。有些服务商（如 Anthropic）会给更细粒度的字段：

```json
// Anthropic 的响应
{
  "stop_reason": "end_turn",       // 模型自主结束
  // 或
  "stop_reason": "stop_sequence",  // 匹配到客户端 stop 
  "stop_sequence": "User:"         // 命中的是哪一个
}
```

#### 使用 stop 参数的注意事项

```swift
// 坑 1: stop 字符串是精确匹配（大小写敏感）
stop: ["User:"]
// 匹配: "User:"    ✅
// 不匹配: "user:"  ❌
// 不匹配: "User :" ❌ (有空格)

// 坑 2: OpenAI 限制最多 4 个 stop 序列
stop: ["A", "B", "C", "D"]        // ✅
stop: ["A", "B", "C", "D", "E"]   // ❌ 报错

// 坑 3: stop 字符不会出现在返回的 content 里
stop: ["User:"]
// 模型可能生成: "Hi there!\nUser: Hi"
// 实际返回: "Hi there!\n"  ← "User:" 及之后的被截掉

// 坑 4: stop 可能跨 token 触发，实现基于累积字符串
// 因为一个 token 可能只包含 stop 的一部分
// 所以必须用 accumulated.hasSuffix() 而不是检查单个 token
```

#### 什么时候该用、不该用 stop？

```
✅ 适合用 stop:
  - Few-shot prompting（只要下一行答案）
  - 角色扮演（防止模型自问自答）
  - 结构化输出（JSON 结束、代码块结束）
  - 格式强约束（只要第一段、只要一句话）

❌ 不该用 stop:
  - 正常对话 → 让模型靠 EOS 自然结束
  - 长文写作 → 用 max_tokens 控制长度
  - 不确定输出格式 → 可能误伤
```

#### 端侧（llama.cpp）的对应实现

用 llama.cpp 时，你要**自己**处理这两种停止：

```swift
func generate(prompt: String, stopSequences: [String] = []) -> AsyncStream<String> {
    AsyncStream { continuation in
        Task {
            var output = ""
            let eosToken = llama_vocab_eos(vocab)
            
            for _ in 0..<maxTokens {
                let nextToken = llama_sampler_sample(sampler, context, -1)
                
                // ========== 停止条件 1: 模型自主停止 ==========
                if nextToken == eosToken {
                    break  // finish_reason ≈ "stop"
                }
                
                let piece = detokenize(nextToken)
                output += piece
                continuation.yield(piece)
                
                // ========== 停止条件 2: 客户端 stop 序列 ==========
                if stopSequences.contains(where: { output.hasSuffix($0) }) {
                    break  // finish_reason ≈ "stop"
                }
                
                try decodeSingle(token: nextToken, position: nCur)
                nCur += 1
            }
            
            // ========== 停止条件 3: 达到 max_tokens ==========
            // 循环自然退出，finish_reason ≈ "length"
            
            continuation.finish()
        }
    }
}
```

#### 一句话总结

> **EOS token = 模型说"我讲完了"（模型决定，不用配置）**
> **stop 参数 = 你说"看到这些字符就让它闭嘴"（你决定，按需配置）**
>
> 两种机制并行存在，满足任一个都会停止生成。

### 2.3 对话历史的管理

这是客户端同学最容易踩坑的地方。**每次请求都要传完整历史**，因为 HTTP 是无状态的。

```swift
class ChatSession {
    private var messages: [Message] = [
        Message(role: "system", content: "You are a helpful assistant.")
    ]
    
    func send(_ userInput: String) async throws -> String {
        // 1. 先把用户输入加进去
        messages.append(Message(role: "user", content: userInput))
        
        // 2. 发起请求（整个历史都传）
        let request = ChatRequest(
            model: "gpt-4o",
            messages: messages,  // ← 每次都传完整历史！
            stream: false,
            temperature: 0.7,
            topP: 1.0,
            maxTokens: 2000,
            stop: nil,
            frequencyPenalty: nil,
            presencePenalty: nil
        )
        
        let response = try await api.send(request)
        
        // 3. 把模型回复也加进历史
        messages.append(Message(role: "assistant", content: response))
        
        return response
    }
}
```

**潜在问题**：

- 对话越长，每次请求越慢（Prefill 时间 = O(历史长度)）
- 对话越长，每次请求越贵（按 input token 计费）
- 对话超出 context window 会被 API 截断或报错

**优化策略**：

```swift
// 策略 1: 滑动窗口（只保留最近 N 轮）
if messages.count > 20 {
    messages = [messages.first!] + messages.suffix(15)  // 保留 system + 最近 15 条
}

// 策略 2: 摘要压缩
if totalTokens > 3000 {
    let summary = await summarize(messages.dropLast(4))
    messages = [
        Message(role: "system", content: systemPrompt),
        Message(role: "assistant", content: "之前的对话摘要：\(summary)")
    ] + messages.suffix(4)
}

// 策略 3: 用 API 提供的会话 ID（部分 API 支持）
// Anthropic/OpenAI Assistants API 可以服务端维护历史
```

### 2.4 流式响应（SSE 协议）详解

流式响应是大模型 API 的**必备能力**，实现"打字机效果"。

**底层协议**：Server-Sent Events（SSE），基于 HTTP 长连接。

#### SSE 响应的样子

```http
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Transfer-Encoding: chunked

data: {"id":"chatcmpl-xxx","choices":[{"delta":{"role":"assistant","content":""}}]}

data: {"id":"chatcmpl-xxx","choices":[{"delta":{"content":"你"}}]}

data: {"id":"chatcmpl-xxx","choices":[{"delta":{"content":"好"}}]}

data: {"id":"chatcmpl-xxx","choices":[{"delta":{"content":"！"}}]}

data: {"id":"chatcmpl-xxx","choices":[{"delta":{},"finish_reason":"stop"}]}

data: [DONE]
```

**关键规则**：

- 每条事件以 `data: ` 开头
- 事件之间用 `\n\n`（空行）分隔
- JSON 里 `delta.content` 是新增的 token
- 最后一行固定是 `data: [DONE]`，标志结束

#### Swift 实现流式解析

```swift
func streamChat(messages: [Message]) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                var request = URLRequest(url: apiURL)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body = ChatRequest(model: "gpt-4o", messages: messages, stream: true, ...)
                request.httpBody = try JSONEncoder().encode(body)
                
                // 关键：使用 URLSession 的流式 API
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw APIError.badStatus
                }
                
                // 逐行读取
                for try await line in bytes.lines {
                    // 空行跳过
                    guard !line.isEmpty else { continue }
                    
                    // 取 data: 后面的部分
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))
                    
                    // [DONE] 标记结束
                    if jsonString == "[DONE]" {
                        continuation.finish()
                        return
                    }
                    
                    // 解析 JSON
                    guard let data = jsonString.data(using: .utf8),
                          let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                          let delta = chunk.choices.first?.delta.content else {
                        continue
                    }
                    
                    // 吐出一个 token
                    continuation.yield(delta)
                }
                
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

struct StreamChunk: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let delta: Delta
        struct Delta: Decodable {
            let content: String?
        }
    }
}
```

### 2.5 错误处理与重试

云端 API 会有各种临时性失败，客户端必须处理：

```swift
enum APIError: Error {
    case rateLimited(retryAfter: TimeInterval)  // 429
    case serverOverloaded                        // 503
    case contextTooLong                          // 输入超出限制
    case invalidAPIKey                           // 401
    case quotaExceeded                           // 余额不足
    case networkTimeout                          // 网络问题
    case contentFiltered                         // 被内容过滤
}

func sendWithRetry(request: ChatRequest, maxRetries: Int = 3) async throws -> String {
    for attempt in 0..<maxRetries {
        do {
            return try await api.send(request)
        } catch APIError.rateLimited(let retryAfter) {
            // 429: 等一会儿再试
            try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
        } catch APIError.serverOverloaded {
            // 503: 指数退避
            let delay = pow(2.0, Double(attempt))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch APIError.invalidAPIKey, APIError.quotaExceeded {
            // 这些错误无法重试
            throw
        }
    }
    throw APIError.serverOverloaded
}
```

### 2.6 主流云端 API 对比

| 提供商 | 代表模型 | 上下文窗口 | 输入定价 | 输出定价 | 特点 |
|---|---|---|---|---|---|
| **OpenAI** | GPT-4o | 128K | $2.5/M | $10/M | 综合能力最强，生态完整 |
| **OpenAI** | GPT-4o-mini | 128K | $0.15/M | $0.6/M | 便宜，够用的日常模型 |
| **Anthropic** | Claude 3.5 Sonnet | 200K | $3/M | $15/M | 代码、推理、长文本最强 |
| **Anthropic** | Claude 3.5 Haiku | 200K | $0.8/M | $4/M | 轻量快速 |
| **Google** | Gemini 1.5 Pro | 2M | $1.25/M | $5/M | 超长上下文之王（2M tokens） |
| **Google** | Gemini 1.5 Flash | 1M | $0.075/M | $0.3/M | 极便宜，速度快 |
| **DeepSeek** | DeepSeek-V3 | 128K | ¥2/M | ¥8/M | 国内最强性价比 |
| **字节** | Doubao-Pro | 32K-256K | ¥0.8/M | ¥2/M | 国内，稳定 |
| **阿里** | Qwen-Max | 128K | ¥20/M | ¥60/M | 中文综合最佳 |

> **M = million，1M tokens ≈ 75 万英文单词 ≈ 50 万汉字**

### 2.7 真实成本估算

```swift
// 一次典型对话的成本估算
struct CostEstimate {
    let model: String = "gpt-4o"
    
    // 系统提示 + 用户输入 + 历史
    let inputTokens: Int = 500
    
    // 模型回复
    let outputTokens: Int = 200
    
    var costUSD: Double {
        // GPT-4o: $2.5/M input, $10/M output
        let inputCost = Double(inputTokens) / 1_000_000 * 2.5
        let outputCost = Double(outputTokens) / 1_000_000 * 10
        return inputCost + outputCost
    }
    
    // 结果: $0.00325，约 2.3 分人民币
}

// 一个 MAU 10 万的 App，每人每天 10 轮对话:
// 100,000 × 10 × 30 × $0.00325 = $9750/月 = 约 7 万人民币/月
```

**省钱策略**：

- 能用小模型就用小模型（GPT-4o-mini 比 GPT-4o 便宜 16 倍）
- 压缩历史，避免重复上下文
- 使用 Prompt Caching（Anthropic/OpenAI 支持，重复前缀可打 9 折）
- 本地缓存常见问答
- 非必要不开 stream（stream 会多消耗 10% 左右）

---

## 三、端侧推理：三种技术方案深度对比

### 3.1 方案 A：llama.cpp（推荐入门）

**原理**：C++ 写的高性能推理引擎，通过量化 + SIMD 优化让 LLM 能在 CPU/GPU 上跑。

```
┌─────────────────────────────────────────────────┐
│  你的 Swift 代码                                  │
│     │ 调用                                         │
│     ▼                                             │
│  Swift 绑定层（.swift 包裹 C 头文件）              │
│     │                                             │
│     ▼                                             │
│  llama.cpp C++ 实现                               │
│     ├─ GGUF 加载器                                 │
│     ├─ Tokenizer（BPE 实现）                       │
│     ├─ 矩阵运算（ggml 库）                         │
│     └─ 后端                                        │
│        ├─ CPU 后端（ARM NEON SIMD）               │
│        └─ Metal 后端（GPU 加速）                   │
└─────────────────────────────────────────────────┘
```

**优点**：

- 社区最活跃，新模型支持最快（新模型通常 1 周内就有 GGUF 版本）
- GGUF 格式通用，HuggingFace 上几千个现成模型
- 量化方案成熟（Q2~Q8 都有）
- 支持 Metal GPU 加速

**缺点**：

- 不能用 Apple Neural Engine（ANE）
- 需要手写 C 桥接代码
- 冷启动稍慢（GGUF 解析）

**适合场景**：想快速跑开源模型、想对比不同模型。

### 3.2 方案 B：CoreML（Apple 原生）

**原理**：Apple 官方推理框架，自动调度 CPU + GPU + ANE。

```
.pt (PyTorch) / .safetensors
    │
    ▼ coremltools 转换
.mlpackage / .mlmodelc
    │
    ▼ Xcode 集成
CoreML Framework
    │
    ▼ 自动选择后端
CPU / GPU / ANE
```

**优点**：

- 能用 ANE，能效比最高（省电、不发热）
- Swift/ObjC 原生 API，无需桥接
- 自动算子融合优化
- Apple 主推，Apple Intelligence 就用这个

**缺点**：

- 模型转换复杂（PyTorch → CoreML 有很多坑）
- 对 LLM 支持较晚（2024 年才有 Stateful KV Cache）
- 社区资源少
- 量化方案选择少

**适合场景**：追求能效比、用 Apple 官方推荐的模型（如 Llama 3.2）。

### 3.3 方案 C：MLX（Apple Silicon 原生）

**原理**：Apple 自研的机器学习框架，专为 M 系列和 A 系列芯片设计。

```
┌───────────────────────────────┐
│  MLX Swift                     │
│  原生 Swift API               │
│     │                          │
│     ▼                          │
│  MLX 核心（C++）               │
│     │                          │
│     ▼                          │
│  Metal Performance Shaders     │
│     │                          │
│     ▼                          │
│  统一内存架构（UMA）           │
│  CPU/GPU 共享同一块内存        │
└───────────────────────────────┘
```

**优点**：

- 原生 Swift，无需 C 桥接
- Lazy Evaluation（类似 PyTorch 的 eager 模式）
- 能做 fine-tuning（不只是推理）
- 动态 shape 支持好

**缺点**：

- 较新，生态尚不成熟
- iOS 支持比 macOS 弱
- 不如 llama.cpp 成熟

**适合场景**：Apple 生态原生开发、需要端侧微调。

### 3.4 三种方案选型矩阵

| 维度 | llama.cpp | CoreML | MLX |
|---|---|---|---|
| **入门难度** | ⭐⭐⭐ 中 | ⭐⭐⭐⭐ 难 | ⭐⭐ 简单 |
| **模型丰富度** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| **能效比** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **性能** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **ANE 支持** | ❌ | ✅ | ❌ |
| **Swift 友好** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **多模态** | ✅ (mtmd) | ✅ | 部分支持 |
| **社区活跃** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **量化方案** | Q2-Q8 | 4-bit | 4-bit |

**本项目选择 llama.cpp，原因**：

1. 模型生态最好，随便换
2. 支持多模态（mtmd 库）
3. Metal 后端性能足够
4. 调试方便（纯 C 代码）

---

## 四、全面对比表：云端 vs 端侧

| 维度 | 云端（API 调用） | 端侧（本地推理） |
|---|---|---|
| **网络** | 必须联网 | 完全离线 |
| **延迟组成** | 网络 + 服务端排队 + 推理 | 纯本地推理 |
| **首字延迟** | 200ms - 2s | 300ms - 3s |
| **生成速度** | 30-100 tokens/s | 10-50 tokens/s（iPhone） |
| **模型能力** | GPT-4 级别 | ≈ GPT-3.5 的 60-70% |
| **上下文窗口** | 128K - 2M | 通常 2K - 32K |
| **隐私** | 数据发到服务器 | 数据不出设备 |
| **成本模型** | 按 token 付费 | 一次下载，终身免费 |
| **开发成本** | 低（调 API） | 高（集成引擎、管理模型） |
| **包体积** | +0 MB | 模型文件 300MB - 3GB |
| **电池** | 每次约 0.01% | 每次约 1-5% |
| **热管理** | 无 | 需要监控 thermalState |
| **失败模式** | 网络 / 限流 / 服务宕机 | OOM / 模型损坏 |
| **迭代速度** | 换模型只改配置 | 要重新下载模型 |
| **审核风险** | 依赖第三方 | 自己可控 |
| **地区限制** | 部分地区无法访问 | 无 |

---

## 五、决策流程图（实战版）

```
需求来了
    │
    ▼
是否强隐私需求？（个人日记、健康数据、密聊）
    ├─ 是 ──────────────────────▶ 端侧模型
    └─ 否
        │
        ▼
    是否需要离线可用？
        ├─ 是 ──────────────────▶ 端侧 + 云端兜底（双引擎）
        └─ 否
            │
            ▼
        任务对模型能力要求？
            ├─ 高（长文写作、复杂推理） ──▶ 云端
            ├─ 中（摘要、分类、翻译）     ──▶ 云端便宜模型 / 端侧都行
            └─ 低（补全、格式化、分类）   ──▶ 端侧（省钱、快）
                │
                ▼
            月活大不大？（成本敏感？）
                ├─ 大 (>10万 DAU) ──▶ 端侧
                └─ 小             ──▶ 云端 + 缓存
```

---

## 六、实战：混合架构设计模式

### 6.1 双引擎降级模式

```swift
protocol AIProvider {
    func chat(messages: [Message]) -> AsyncThrowingStream<String, Error>
}

class CloudProvider: AIProvider { /* 调 OpenAI API */ }
class OnDeviceProvider: AIProvider { /* 调 llama.cpp */ }

class HybridProvider: AIProvider {
    let cloud: CloudProvider
    let onDevice: OnDeviceProvider
    let reachability: Reachability
    
    func chat(messages: [Message]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // 1. 尝试云端
                if reachability.isConnected {
                    do {
                        for try await token in cloud.chat(messages: messages) {
                            continuation.yield(token)
                        }
                        continuation.finish()
                        return
                    } catch {
                        // 云端失败，降级到端侧
                        print("Cloud failed: \(error), fallback to on-device")
                    }
                }
                
                // 2. 降级到端侧
                do {
                    for try await token in onDevice.chat(messages: messages) {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

### 6.2 任务路由模式

```swift
class SmartRouter {
    let cloudHeavy: AIProvider   // GPT-4o
    let cloudLight: AIProvider   // GPT-4o-mini
    let onDevice: AIProvider     // Qwen2.5-1.5B
    
    func chat(task: Task) -> AsyncThrowingStream<String, Error> {
        switch task.complexity {
        case .simple:
            return onDevice.chat(messages: task.messages)        // 省钱 + 隐私
        case .medium:
            return cloudLight.chat(messages: task.messages)      // 便宜够用
        case .complex:
            return cloudHeavy.chat(messages: task.messages)      // 贵但强
        }
    }
}

// 任务复杂度判定（简单的启发式）
func estimateComplexity(_ prompt: String) -> Task.Complexity {
    let len = prompt.count
    let hasCode = prompt.contains("```") || prompt.contains("code")
    let hasMath = prompt.contains(where: { $0.isNumber })
    
    switch (len, hasCode, hasMath) {
    case (..<100, false, false):  return .simple
    case (100..<500, _, _):        return .medium
    default:                       return .complex
    }
}
```

### 6.3 缓存模式（省钱大杀器）

```swift
class CachedProvider: AIProvider {
    let backend: AIProvider
    let cache = NSCache<NSString, NSString>()
    
    func chat(messages: [Message]) -> AsyncThrowingStream<String, Error> {
        let key = messages.map { "\($0.role):\($0.content)" }.joined(separator: "|")
        let nsKey = NSString(string: key)
        
        if let cached = cache.object(forKey: nsKey) {
            return AsyncThrowingStream { continuation in
                continuation.yield(String(cached))
                continuation.finish()
            }
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                var full = ""
                do {
                    for try await token in backend.chat(messages: messages) {
                        full += token
                        continuation.yield(token)
                    }
                    cache.setObject(NSString(string: full), forKey: nsKey)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

---

## 七、典型端侧模型及对应设备

| 模型 | 参数量 | Q4 大小 | 最低设备 | 推荐设备 | 速度（16 Pro） |
|---|---|---|---|---|---|
| Qwen2.5-0.5B | 0.5B | 300MB | iPhone 12 | iPhone 13 | ~60 t/s |
| Llama 3.2 1B | 1B | 700MB | iPhone 13 | iPhone 14 | ~40 t/s |
| Qwen2.5-1.5B | 1.5B | 1.0GB | iPhone 14 | iPhone 15 | ~30 t/s |
| Gemma 2 2B | 2B | 1.5GB | iPhone 15 | iPhone 15 Pro | ~25 t/s |
| Llama 3.2 3B | 3B | 1.8GB | iPhone 15 Pro | iPhone 16 Pro | ~20 t/s |
| Phi-3-mini 3.8B | 3.8B | 2.2GB | iPhone 15 Pro | iPhone 16 Pro | ~18 t/s |
| Qwen2.5-7B | 7B | 4.5GB | iPad Pro M4 | iPad Pro M4 | ~15 t/s |

> Q4 = Q4_K_M 量化，对于 iPhone 是精度与大小的最佳平衡点。

---

## 八、总结：该用哪个？

- **如果你在做 Demo 或 POC**：先上云端，快速验证需求
- **如果你做键盘、输入法等高频小任务**：端侧（延迟 + 隐私）
- **如果你做客服、长文写作等能力要求高的**：云端（大模型）
- **如果你做金融、医疗等隐私敏感场景**：端侧（合规）
- **如果你做海外产品，要支持全球网络**：端侧（网络不确定）
- **如果你做 MAU 百万级的 App**：混合（省成本 + 兜底）

**终极原则**：客户端同学不要把端侧 AI 当成"云端的替代品"，它是**互补**的，不是**替代**的。

---

## 下一步

理解了两种部署方式的选择后，我们深入看 Dense 模型的底层原理 → [03 - 纯文本模型（Dense）：Transformer 架构深度解析](03-text-models.md)

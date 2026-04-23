# 01 - AI 基础：大模型到底是什么，以及它是怎么运行的

> 写给 iOS 客户端开发者的大模型入门。不讲数学公式，全部用你每天在写的代码类比，让你看完这一篇就真正理解大模型在手机里是**怎么跑起来**的。

## 读这篇你能收获什么

- 搞清楚"大模型"这三个字到底指什么（文件？函数？服务？）
- 理解 Token / Embedding / 参数 / 推理 这些术语的**实际含义**
- 看懂大模型"打字"效果的底层机制（为什么是一个字一个字蹦出来）
- 掌握评估端侧模型性能的所有关键指标
- 明白为什么 iPhone 运行大模型的瓶颈是**内存**不是算力

---

## 一、大模型到底是什么东西？

### 三个常见误解

很多客户端同学第一次接触大模型时，会有以下误解：

| 误解 | 实际情况 |
|---|---|
| "大模型是一个超级聪明的程序" | ❌ 它就是一个**数学函数**，输入数字，输出数字 |
| "大模型存储了所有知识" | ❌ 它只是学会了"在 XX 上下文里，下一个词最可能是 YY"这种统计规律 |
| "大模型每次都在思考" | ❌ 它**不会思考**，只是在做矩阵乘法，每次只预测"下一个 token" |

### 正确的心智模型

```
大模型 = 一个函数（本质） + 一堆参数（文件） + 一套运行时（代码）

类比 iOS:
  函数签名   = func predict(input: [Int]) -> [Float]
  参数       = .gguf 文件里存的几十亿个浮点数（就是"知识"）
  运行时     = llama.cpp / CoreML / MLX 这些推理引擎
```

**这就是为什么你运行大模型时要做三件事**：

```swift
// 1. 加载参数文件（把 .gguf 里的几十亿个数字读进内存）
let model = llama_load_model_from_file("qwen2.5-1.5b.gguf", ...)

// 2. 创建运行时上下文（分配计算所需的缓冲区）
let context = llama_new_context_with_model(model, ...)

// 3. 调用函数（喂入 token，拿到下一个 token）
let nextToken = llama_decode(context, inputTokens)
```

### 关键概念速查表（iOS 开发者版）

| 概念 | 英文 | iOS 类比 | 实际含义 |
|---|---|---|---|
| 模型 | Model | `.mlmodel` 文件 | 保存了所有参数的二进制文件 |
| 参数 | Parameters / Weights | `UserDefaults` 里的几十亿个 Float | 训练学到的数字，决定模型行为 |
| 推理 | Inference | `model.prediction(from:)` | 喂输入拿输出的过程 |
| Token | Token | `Character` 或 `String.Index` | 文本被切分后的最小单位 |
| Tokenizer | Tokenizer | 类似 `String → [Int]` 的编码器 | 把文本变成数字的查表工具 |
| Embedding | Embedding | `Dictionary<Int, [Float]>` | 把 token 数字变成向量 |
| 上下文窗口 | Context Window | `buffer.capacity` | 模型一次能"看到"的 token 数上限 |
| 量化 | Quantization | 类似 JPEG 压缩 | 用更少的 bit 存储每个参数 |
| Prefill | Prefill | 类似异步加载首屏 | 处理输入 prompt 的阶段 |
| Decode | Decode | 类似流式下载 | 逐个生成输出 token 的阶段 |
| KV Cache | KV Cache | 类似 `NSCache` | 缓存中间计算结果，避免重复计算 |
| 采样 | Sampling | 类似 `randomElement()` | 从候选词里选一个作为输出 |

---

## 二、文本是怎么变成数字的：Tokenizer 和 Embedding

这是大模型里最**底层**的两步，也是客户端同学最容易忽视的。

### Step 1: Tokenize —— 文本切成 token

大模型看不懂字符串，只认整数。所以输入要先"翻译"成数字 ID。

```
用户输入: "你好世界"
          ↓ Tokenizer
Token:    ["你好", "世界"]              (切词)
          ↓ 查词表
Token ID: [45678, 12345]                (变成整数)
```

**Token ID 是什么？** 每个模型都有一张固定的**词表（vocabulary）**，通常有 10 万到 15 万个条目。Token ID 就是这张词表里的索引。

```swift
// 类比 iOS：就像一张超大的 String → Int 映射表
let vocabulary: [String: Int] = [
    "hello": 1,
    "world": 2,
    "你好": 45678,
    "世界": 12345,
    // ... 共 151,936 个条目（以 Qwen2.5 为例）
]

func tokenize(_ text: String) -> [Int] {
    // 实际用的是 BPE (Byte-Pair Encoding) 算法
    // 会把长词切成常见的子词
    return splitToSubwords(text).map { vocabulary[$0]! }
}
```

### 为什么 token 不等于"字"？

这是新手最常见的困惑：

```
"Hello"       = 1 个 token  (常见英文单词)
"你好"        = 1 个 token  (常见中文词)
"ChatGPT"     = 2 个 token  ("Chat" + "GPT")
"abcdefg"     = 可能 3-4 个 token (不常见的字符组合)
"🚀"          = 3 个 token  (emoji 通常被切成字节)

结论：
  英文一般 1 token ≈ 0.75 个单词
  中文一般 1 token ≈ 1-2 个字
  这就是为什么 API 计费按 token 算
```

### Step 2: Embedding —— token 变成向量

光有整数 ID 还不够，因为整数 ID 之间没有"语义关系"（45678 和 45679 的距离毫无意义）。

所以还要再查一张表：**Embedding 表**，把每个 token ID 变成一个**高维向量**。

```
Token ID: 45678  (代表 "你好")
          ↓ 查 Embedding 表
Vector:   [0.12, -0.34, 0.78, 0.22, ..., 0.55]  (2048 维)
```

**这张 Embedding 表长什么样？**

```swift
// 想象成一个超大的字典
// key 是 token ID，value 是一串 Float
let embeddingTable: [Int: [Float]] = [
    1:     [0.15, 0.22, -0.11, ...],  // "hello" 的向量
    2:     [0.18, 0.25, -0.09, ...],  // "world" 的向量
    45678: [0.12, -0.34, 0.78, ...],  // "你好" 的向量
    // ... 共 151,936 个向量，每个向量 2048 维
]

// 所以 Embedding 表本身就是一个巨大的二维矩阵：
// 形状: [151936, 2048] = 约 3 亿个 Float = 占用约 600MB（FP16）
```

这张表就占了模型参数量的一大块。模型在训练时会调整这张表，让**语义相似的词**有**相似的向量**：

```
vec("猫") ≈ vec("小猫")       (距离近)
vec("猫") ≈ vec("狗")          (距离较近，都是动物)
vec("猫") ≠ vec("汽车")        (距离远)
```

### iOS 类比：整个流程就像 UIImage 加载链

```
用户输入文本 (你好世界)
    ↓ Tokenize         类比: UIImage(named:) 查找图片名
Token IDs [45678, 12345]
    ↓ Embedding        类比: UIImage → CGImage 解码成像素
Vectors [[...], [...]]
    ↓ Transformer      类比: Core Image 滤镜处理
处理后的 Vectors
    ↓ Output Projection  类比: CGImage → PNG 编码
概率分布
    ↓ Sampling         类比: 从概率里选一个
下一个 Token
```

---

## 三、大模型是怎么"说话"的：自回归生成

### 核心机制：一次只预测一个 token

这是理解大模型"打字机效果"的关键。

```
用户输入: "写一首关于iOS的诗"

模型内部发生的事（第一轮）:
  输入 tokens: [写, 一首, 关于, iOS, 的, 诗]
        ↓ 整个模型跑一遍
  输出: 一个"概率分布"
        {代: 0.42, 程: 0.15, 让: 0.08, 用: 0.05, ...}
        ↓ 从中采样
  选出: "代"
        ↓ 把 "代" 拼回输入
        
第二轮:
  输入 tokens: [写, 一首, 关于, iOS, 的, 诗, 代]
        ↓ 整个模型再跑一遍
  输出概率分布: {码: 0.78, 替: 0.05, ...}
  选出: "码"

第三轮:
  输入 tokens: [写, 一首, 关于, iOS, 的, 诗, 代, 码]
  ...

直到采样到 <|endoftext|> 特殊 token，才停止。
```

**这就是为什么输出像打字机**：不是故意的动画效果，而是模型**物理上每次只能生成一个 token**。

### iOS 代码类比：就像一个 while 循环

```swift
func generate(prompt: String) -> String {
    var tokens = tokenize(prompt)
    var output = ""
    
    while output.count < maxLength {
        // 把当前所有 tokens 喂给模型
        let logits = model.forward(tokens)  // 输出 151,936 维的概率分布
        
        // 从概率分布里采样一个 token
        let nextToken = sample(logits)
        
        if nextToken == EOS_TOKEN {
            break  // 遇到结束符，停止
        }
        
        tokens.append(nextToken)
        output += detokenize(nextToken)
    }
    
    return output
}
```

### 两个关键阶段：Prefill 和 Decode

```
┌──────────────────────────────┐     ┌──────────────────────────────┐
│      Prefill 阶段             │────▶│       Decode 阶段             │
│                               │     │                               │
│  处理用户输入的 prompt         │     │  逐个生成新的 token           │
│  "写一首关于iOS的诗"           │     │  "代" → "码" → "之" → "美"    │
│                               │     │                               │
│  所有输入 token 并行计算       │     │  必须串行，一次只生成 1 个    │
│  GPU 可以吃满                 │     │  GPU 大部分时间在等内存       │
│                               │     │                               │
│  耗时短 (100-500ms)            │     │  耗时长 (每 token 30-100ms)   │
│  决定"首字延迟 (TTFT)"          │     │  决定"生成速度 (TPS)"         │
└──────────────────────────────┘     └──────────────────────────────┘
```

这两个阶段为什么差别这么大？

- **Prefill** 时，你有 100 个输入 token，可以**一次性**扔给 GPU 并行计算
- **Decode** 时，你要生成第 101 个 token，**必须**先算出来才能算第 102 个，无法并行

所以大模型推理中**真正的瓶颈**是 Decode 阶段。

### 性能指标怎么算？

```swift
struct InferenceMetrics {
    // 首字延迟 (Time To First Token)
    let ttft: TimeInterval
    
    // Prefill 速度（每秒处理多少个输入 token）
    let prefillSpeed: Double  // tokens/sec，通常 100-500 t/s
    
    // Decode 速度（每秒生成多少个输出 token）
    let decodeSpeed: Double   // tokens/sec，通常 10-50 t/s（iPhone 上）
    
    // 用户感知：
    // - TTFT < 1s：感觉流畅
    // - TTFT > 3s：感觉卡顿
    // - Decode > 20 t/s：阅读速度跟得上
    // - Decode < 5 t/s：感觉很慢
}
```

---

## 四、KV Cache：让生成加速的关键优化

这是客户端同学最容易忽视但又极其重要的概念。**不理解 KV Cache，就不理解为什么长对话会越来越慢、越来越占内存。**

### 没有 KV Cache 的问题

前面讲的朴素生成有个致命问题：

```
生成第 100 个 token 时：
  输入: [token_1, token_2, ..., token_99]
  计算: 99 个 token 每个都要跟其他所有 token 算注意力
  
生成第 101 个 token 时：
  输入: [token_1, token_2, ..., token_100]
  计算: 100 个 token 又全部重算一遍！
  
浪费大量重复计算！
```

### KV Cache 的优化

```
关键观察：token_1 到 token_99 的中间计算结果，
         在生成第 100 个 token 和第 101 个 token 时是完全一样的！
         
所以：把这些中间结果（叫 Key 和 Value 向量）缓存起来。
      生成新 token 时，只需要算新 token 的，然后跟缓存拼起来。
```

### iOS 代码类比

```swift
// 没有 KV Cache（朴素实现）
func generateNaive() {
    var tokens: [Int] = [...]
    while !done {
        // 每次都把所有 token 从头算一遍
        let logits = model.forward(tokens)  // 慢！
        tokens.append(sample(logits))
    }
}

// 有 KV Cache（实际实现）
func generateWithCache() {
    var tokens: [Int] = [...]
    var kvCache: KVCache = .empty       // 类似 NSCache
    
    // Prefill: 一次性处理初始 prompt，缓存所有中间结果
    let logits = model.forward(tokens, cache: &kvCache)
    tokens.append(sample(logits))
    
    while !done {
        // Decode: 只传新的 token，复用缓存
        let newToken = tokens.last!
        let logits = model.forward([newToken], cache: &kvCache)  // 快！
        tokens.append(sample(logits))
    }
}
```

### KV Cache 的内存占用

```
KV Cache 大小公式：
  cache_size = 2 × n_layers × n_heads × head_dim × seq_len × bytes_per_float

以 Qwen2.5-1.5B 为例 (FP16):
  2 × 28 × 12 × 128 × 2048 × 2 = 352 MB

关键特性：
  - cache 随对话长度线性增长
  - 长对话到最后可能 cache 比模型本身还大
  - 这就是为什么 iPhone 上要限制 n_ctx（上下文窗口）
```

---

## 五、采样：怎么从概率分布里选出下一个 token

模型每次输出的不是一个 token，而是**所有可能 token 的概率分布**。怎么从中选一个？这叫"采样"。

### 最简单的方案：Greedy（贪心）

```swift
func sample(logits: [Float]) -> Int {
    return logits.indices.max { logits[$0] < logits[$1] }!
    // 永远选概率最高的那个
}
```

**问题**：输出永远一样，毫无创造性。问同一个问题永远同一个答案。

### 实用方案：Temperature + Top-K + Top-P

这三个参数就是你在调用模型时最常见的三个旋钮：

```swift
struct GenerationConfig {
    var temperature: Float   // 0.0 ~ 2.0，控制随机性
    var topK: Int           // 只从概率最高的 K 个里采样
    var topP: Float         // 只从累积概率达到 P 的 token 里采样
}
```

### Temperature（温度）：控制"随机程度"

```
原始概率分布:
  "好" : 0.50
  "棒" : 0.30
  "差" : 0.15
  "烂" : 0.05

Temperature = 0.1 (低，接近贪心):
  "好" : 0.92  ← 基本总是选这个
  "棒" : 0.07
  "差" : 0.01
  "烂" : 0.00
  效果: 保守，重复，确定性高

Temperature = 1.0 (默认):
  保持原始分布

Temperature = 2.0 (高):
  "好" : 0.32
  "棒" : 0.28
  "差" : 0.22
  "烂" : 0.18
  效果: 随机性强，有创造性但可能跑偏
```

**数学上**：`new_prob = softmax(logits / temperature)`。

### Top-K：只看前 K 个候选

```
词表总大小: 151,936 个
Top-K = 40:
  只保留概率最高的 40 个 token，其他全部归零
  再从这 40 个里按概率采样
```

### Top-P（核采样）：只看累积概率前 P 的候选

```
按概率排序后:
  "好" : 0.50 (累积 0.50)
  "棒" : 0.30 (累积 0.80)  ← Top-P=0.9 在这里切
  "差" : 0.15 (累积 0.95)
  "烂" : 0.05 (累积 1.00)
  
Top-P = 0.9 时，只保留 "好" 和 "棒"，
因为它们加起来已经覆盖了 80% 的概率质量，
再取一个 "差"（累积到 95%）就超过 P=0.9 了。
```

### 实际推荐配置

```swift
// 对话场景（平衡）
let chatConfig = GenerationConfig(
    temperature: 0.7,
    topK: 40,
    topP: 0.9
)

// 代码生成（确定性）
let codeConfig = GenerationConfig(
    temperature: 0.2,
    topK: 10,
    topP: 0.5
)

// 创意写作（发散）
let creativeConfig = GenerationConfig(
    temperature: 1.0,
    topK: 50,
    topP: 0.95
)

// 分类任务（纯确定）
let classifyConfig = GenerationConfig(
    temperature: 0.0,  // 等价于贪心
    topK: 1,
    topP: 1.0
)
```

---

## 六、模型的"大"到底有多大？

### 参数量对比

```
云端巨无霸（iPhone 完全跑不动）:
  GPT-4         : ~1.8T 参数   (约 1.8 万亿)
  Claude 3.5    : ~400B 参数   (未公开)
  Llama 3.1     : 405B 参数
  DeepSeek-V3   : 671B 参数

服务器/工作站:
  Llama 3 70B   : 70B 参数     (需要 A100 以上)
  Qwen2.5 72B   : 72B 参数
  
高端笔记本 (Mac Studio):
  Llama 3.1 8B  : 8B 参数
  Qwen2.5 7B    : 7B 参数

iPhone 可运行 🎯:
  Phi-3-mini    : 3.8B 参数    (iPhone 15 Pro+)
  Llama 3.2 3B  : 3B 参数      (iPhone 15 Pro+)
  Gemma 2 2B    : 2B 参数      (iPhone 15+)
  Qwen2.5 1.5B  : 1.5B 参数    (iPhone 14+)
  Llama 3.2 1B  : 1B 参数      (iPhone 13+)
  Qwen2.5 0.5B  : 0.5B 参数    (iPhone 12+)
```

### 参数量和文件大小的换算

```
存储格式决定了一个参数占多少字节:

FP32 (32位浮点): 每个参数 4 字节
  1B 参数 ≈ 4 GB

FP16 (16位浮点): 每个参数 2 字节   ← 训练完的原始格式
  1B 参数 ≈ 2 GB

INT8 量化: 每个参数 1 字节         ← 轻度压缩
  1B 参数 ≈ 1 GB

INT4 量化 (Q4_K_M): 每个参数 ~0.5 字节   ← 端侧首选
  1B 参数 ≈ 0.5-0.7 GB

例：Qwen2.5-1.5B 在不同精度下的文件大小
  FP16:    3.0 GB  (原版)
  Q8:      1.6 GB
  Q4_K_M:  1.0 GB  ← 最常用
  Q2_K:    0.7 GB  (质量明显下降)
```

### iPhone 的真实内存限制

**一个关键认知**：iOS 不会让你用光全部 RAM！

```
iPhone 15 Pro 的 8GB RAM 实际分配:
  iOS 系统          : ~2 GB
  系统服务/后台      : ~1.5 GB
  你的 App 硬限制    : 约 3-4 GB (超出会被 Jetsam 杀掉)
  
所以实际上:
  模型文件 + KV Cache + 其他开销 < 3GB
  
这就是为什么实际选模型的指导原则:
  Q4 量化后的文件大小 < 2.5GB
  否则 KV Cache 一长就 OOM
```

### 设备选型速查

| 设备 | RAM | 能跑的最大 Q4 模型 | 推荐模型 |
|---|---|---|---|
| iPhone 12/13 | 4-6 GB | ~1 GB | Qwen2.5-0.5B, Llama 3.2 1B |
| iPhone 14 | 6 GB | ~1.5 GB | Qwen2.5-1.5B |
| iPhone 15 | 6 GB | ~1.5 GB | Qwen2.5-1.5B, Gemma 2 2B |
| iPhone 15 Pro | 8 GB | ~2.5 GB | Llama 3.2 3B, Phi-3-mini |
| iPhone 16 Pro | 8 GB | ~2.5 GB | 同上，但速度更快 |
| iPad Pro M4 | 16 GB | ~8 GB | Qwen2.5-7B, Llama 3.1 8B |

> **铁律**：端侧 AI 的第一限制永远是**内存**，不是算力。iPhone 的 Neural Engine 和 GPU 都很强，但你装不下模型就一切免谈。

---

## 七、为什么 iPhone 适合跑大模型？

### 大模型推理的本质：内存带宽受限

这是反直觉的——你以为瓶颈是算力，其实是**从内存里把参数读出来的速度**。

```
推理一个 token 需要做什么:
  1. 把所有 3B 参数从 RAM 读到寄存器  ← 耗时 90%
  2. 做一次矩阵乘法                    ← 耗时 10%

所以真正的瓶颈是：
  内存带宽 (memory bandwidth)

iPhone 的优势:
  统一内存架构 (UMA) + 超宽内存带宽
  iPhone 15 Pro: ~51 GB/s
  iPhone 16 Pro: ~120 GB/s
  
对比:
  DDR5 内存台式机: ~50 GB/s
  RTX 4090:      ~1000 GB/s (但无法插进手机)
  Mac Studio M2 Ultra: ~800 GB/s
```

### iPhone 的三个硬件资源

```swift
// iPhone 上有三种可用的计算单元
enum ComputeUnit {
    case cpu         // 通用 CPU（6 核 Apple Silicon）
    case gpu         // Metal GPU（10-20 核）
    case neuralEngine // ANE (Apple Neural Engine, 16 核 NPU)
}

// 不同推理框架的利用情况:
// llama.cpp:  CPU + Metal GPU
// CoreML:     CPU + GPU + ANE（全能）
// MLX:        CPU + GPU（苹果自研，原生 Swift）

// 重点:
// - ANE 只能跑 CoreML 转换后的模型
// - ANE 能效比最高（省电、不发热）
// - 但 ANE 对模型算子支持有限，大模型用 ANE 很难
```

---

## 八、端侧 AI 的现实局限

### 能力天花板

```
3B 端侧模型能做什么:
  ✅ 基础对话、问答
  ✅ 文本摘要、翻译
  ✅ 简单代码补全
  ✅ 情感分析、分类
  ✅ 格式化输出（JSON）

3B 端侧模型做不好什么:
  ❌ 复杂推理（数学证明、多步规划）
  ❌ 长文创作（容易跑题、重复）
  ❌ 精准知识问答（没见过的冷门知识会瞎编）
  ❌ 精确代码生成（边界情况容易错）

≈ 3B 模型 的能力约等于 GPT-3.5 的 60-70%
```

### 发热与降频

```
ProcessInfo.processInfo.thermalState 的五个状态:

.nominal   ✅ 正常，全速推理
.fair      🟡 微热，可继续
.serious   🟠 过热，iOS 会强制降频（性能下降 30-50%）
.critical  🔴 危险，必须停止密集计算

实际测试:
  iPhone 15 Pro 持续推理 1.5B 模型:
    0-2 分钟:  25 tokens/s
    2-5 分钟:  20 tokens/s  (开始降频)
    5-10 分钟: 12 tokens/s  (明显降频)
    
所以：
  - 对话场景：影响不大（有思考间隔）
  - 批量处理：必须加冷却间隔
```

### 模型下载问题

```
用户愿意下载多大的 App?
  10 MB:  几乎所有人
  100 MB: 大部分人
  500 MB: 需要说明理由
  1 GB+:  只有核心用户

所以端侧 AI 的落地策略:
  1. App 本体不带模型（否则 App Store 审核就难过）
  2. 首次使用时按需下载
  3. 清楚告知模型大小和预估下载时间
  4. 支持 Wi-Fi 限制
  5. 支持断点续传
  6. 提供多个模型让用户选（小精度低 vs 大精度高）
```

---

## 九、对 iOS 开发者意味着什么？

### 端侧 AI 的场景

```
✅ 非常适合:
  - 键盘/输入法的智能建议
  - 照片元数据生成（描述、标签）
  - 本地笔记的摘要、续写
  - 离线翻译
  - 对隐私极敏感的场景（日记、健康）
  - 需要低延迟的场景（VoiceOver 辅助）

⚠️ 慎重考虑:
  - 客服对话（能力不够）
  - 代码助手（3B 模型质量差）
  - 长文创作（容易跑题）

❌ 不适合:
  - 需要最新知识（模型训练数据有截止日期）
  - 精确计算（让模型算 123456 × 789 不靠谱）
  - 专业医疗/法律建议
```

### 和云端模型的配合

```
最佳实践：混合架构

用户请求
   ↓
简单任务? ──Yes──▶ 端侧模型 (离线、免费、快)
   │                   │
   No                 失败降级
   ↓                   ↓
复杂任务 ──────────▶ 云端模型 (GPT-4/Claude)

案例：
  - 消息/笔记的自动分类    → 端侧（隐私 + 免费）
  - 智能回复建议           → 端侧（低延迟）
  - "写一篇 1000 字文章"   → 云端（能力要求高）
  - 网络断开时              → 降级到端侧
```

---

## 十、这一篇的核心收获

再次强调你应该牢记的几个核心事实：

1. **大模型 = 数学函数 + 参数文件 + 运行时**，没有魔法
2. **文本 → Token → Embedding → 向量**，模型只认向量
3. **自回归生成**：每次只预测一个 token，所以有打字机效果
4. **KV Cache** 是所有推理加速的基础，理解它才能理解长对话为什么越来越慢
5. **Temperature/TopK/TopP** 是你调模型效果的三个核心旋钮
6. **端侧瓶颈是内存而不是算力**，iPhone 因为统一内存架构才适合跑大模型
7. **Prefill 决定首字延迟，Decode 决定生成速度**，这是所有 benchmark 的核心指标

有了这些基础，下一篇我们看 → [02 - 云端 vs 端侧：两种部署方式的深度对比](02-model-categories.md)

# 03 - 纯文本模型（Dense Model）详解

> 理解最基础的模型架构 —— Transformer Dense Model，为后续理解 MoE 打基础。

## 什么是"纯文本模型"？

这里的"纯文本"指的是模型架构是 **Dense（稠密）** 的，即：

- **每次推理，所有参数都参与计算**
- 与之对比的是 MoE（混合专家），只激活部分参数

### 用 iOS 类比理解 Dense Model

```
Dense Model 就像一个 UIViewController，每次 viewDidLoad 都会：
- 初始化所有子视图 (所有参数都参与)
- 设置所有约束
- 绑定所有数据

MoE Model 就像一个 UIPageViewController：
- 只加载当前页和相邻页 (只激活部分专家)
- 其他页面按需加载
- 更省资源
```

## Transformer 架构入门

### 不需要懂数学，只需要理解数据流

```
输入: "今天天气真"

Step 1: Tokenize (分词)
"今天" → Token_1
"天气" → Token_2  
"真"   → Token_3

Step 2: Embedding (向量化)
Token_1 → [0.12, -0.34, 0.56, ...]  ← 每个 token 变成一串数字
Token_2 → [0.78, 0.23, -0.45, ...]
Token_3 → [0.11, 0.89, 0.33, ...]

Step 3: Transformer Layers (多层处理)
┌─────────────────────────────────┐
│  Layer 1: Self-Attention        │  ← 让每个 token "看到"其他 token
│           + Feed Forward        │  ← 对信息进行变换处理
├─────────────────────────────────┤
│  Layer 2: Self-Attention        │  ← 再次处理，理解更深
│           + Feed Forward        │
├─────────────────────────────────┤
│  ...重复 N 层...                │  ← 层数越多，理解越深
├─────────────────────────────────┤
│  Layer N: Self-Attention        │
│           + Feed Forward        │
└─────────────────────────────────┘

Step 4: Output (输出)
处理后的向量 → 概率分布 → "好" (概率最高的下一个 token)
```

### Self-Attention 直觉理解

```
句子: "苹果发布了新的iPhone"

Self-Attention 让模型理解：
- "苹果" → 这里指公司（Apple），不是水果
- 因为 "苹果" 和 "发布"、"iPhone" 有强关联
- 这种"关联权重"就是 Attention

类比 iOS：
就像 AutoLayout 的约束关系，
每个 view (token) 都和其他 views 有约束 (attention)，
约束越强，关系越紧密。
```

## 端侧常用的 Dense 模型

### 模型家族一览

```
Meta Llama 家族:
├── Llama 3.2 1B    ← 最轻量，基础对话
├── Llama 3.2 3B    ← 均衡选择
└── Llama 3.1 8B    ← 能力强，需要高端设备

Google Gemma 家族:
├── Gemma 2B        ← 轻量级
└── Gemma 7B        ← 能力较强

Microsoft Phi 家族:
├── Phi-3-mini 3.8B ← 推理能力突出
└── Phi-3.5-mini    ← 改进版

阿里 Qwen 家族:
├── Qwen2.5-0.5B   ← 超轻量
├── Qwen2.5-1.5B   ← 中文优秀
└── Qwen2.5-3B     ← 中文最佳
```

### 模型大小与能力的关系

```
参数量:   0.5B ──── 1B ──── 2B ──── 3B ──── 7B ──── 13B
能力:     基础    简单    不错    良好    较强    很强
速度:     极快    很快    快      适中    慢      很慢
内存:     ~0.3GB  ~0.7GB  ~1.5GB  ~2GB   ~4.5GB  ~8GB
          (Q4)    (Q4)    (Q4)    (Q4)   (Q4)    (Q4)
          
iPhone    ✅      ✅      ✅      ✅*    ⚠️*    ❌
可运行?   所有    所有    15+     15Pro+  Pro+    不建议

* 需要量化到 Q4 或更低
```

## 量化：让大模型塞进 iPhone

### 什么是量化？

```
原始参数: 0.123456789 (FP32, 32位浮点, 4字节)
                ↓ 量化
量化参数: 0.12 (FP16, 16位浮点, 2字节)  ← 体积减半
                ↓ 进一步量化
量化参数: 2 (INT4, 4位整数, 0.5字节)    ← 体积减到 1/8

类比：
FP32 → 原始 RAW 照片 (最高质量)
FP16 → HEIC 照片 (几乎无损)
INT8 → 高质量 JPEG (轻微损失)
INT4 → 中等 JPEG (有损失但可接受)
```

### 量化方案对比

| 量化级别 | 体积比 | 精度影响 | 速度影响 | 推荐场景 |
|---------|--------|---------|---------|---------|
| FP16 | 1x (基准) | 无 | 基准 | 服务器 |
| INT8 (Q8) | 0.5x | 极小 | 快 10-20% | 高端设备 |
| INT4 (Q4) | 0.25x | 小 | 快 30-50% | iPhone 推荐 |
| INT3 (Q3) | 0.19x | 中等 | 快 40-60% | 内存极紧张 |
| INT2 (Q2) | 0.13x | 较大 | 最快 | 不推荐 |

> **推荐**：对于 iPhone 端侧模型，**Q4_K_M** 是最佳平衡点。

## 在 iOS 上运行 Dense 模型

### 方案 1: 使用 llama.cpp（推荐入门）

```swift
// 概念示意 - 实际实现见 Demo 代码
class LlamaCppEngine {
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    
    func loadModel(path: String) {
        // 加载 GGUF 格式的量化模型
        let params = llama_model_default_params()
        model = llama_load_model_from_file(path, params)
        
        // 创建推理上下文
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = 2048  // 上下文窗口大小
        context = llama_new_context_with_model(model, ctxParams)
    }
    
    func generate(prompt: String) async -> AsyncStream<String> {
        // 1. Tokenize: 将文本转为 token 序列
        // 2. Prefill: 处理 prompt
        // 3. Decode: 逐个生成 token
        // 4. Detokenize: 将 token 转回文本
    }
}
```

### 方案 2: 使用 CoreML

```swift
// 概念示意
class CoreMLEngine {
    private var model: MLModel?
    
    func loadModel() throws {
        // CoreML 模型需要预先转换为 .mlpackage 格式
        let config = MLModelConfiguration()
        config.computeUnits = .all  // 使用 CPU + GPU + NPU
        model = try MLModel(contentsOf: modelURL, configuration: config)
    }
}
```

### 关键性能指标

在代码中需要测量的指标：

```swift
struct BenchmarkMetrics {
    let modelName: String
    let modelSize: Int64                // 模型文件大小 (bytes)
    let loadTime: TimeInterval          // 模型加载时间
    let prefillTime: TimeInterval       // Prefill 耗时
    let prefillTokensPerSecond: Double  // Prefill 速度 (tokens/s)
    let decodeTokensPerSecond: Double   // 生成速度 (tokens/s)
    let timeToFirstToken: TimeInterval  // 首 token 延迟
    let peakMemory: UInt64              // 峰值内存 (bytes)
    let totalTokens: Int                // 总生成 token 数
}
```

## 下一步

理解了 Dense 模型后，来看更高级的架构 → [04 - MoE 模型详解](04-moe-models.md)

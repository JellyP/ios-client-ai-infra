# 05 - 端侧部署实践指南

> 从下载模型到在 iPhone 上跑起来的完整流程。

## 端侧部署全景图

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ 选择模型  │───▶│ 量化转换  │───▶│ 集成到App │───▶│ 性能优化  │
│          │    │          │    │          │    │          │
│ HuggingFace│  │ GGUF/CoreML│  │ 加载推理  │    │ Benchmark│
└──────────┘    └──────────┘    └──────────┘    └──────────┘
```

## Step 1: 选择模型

### 选模型的核心考量

```
三角约束（类似 CAP 定理）：

        能力 (Quality)
         /\
        /  \
       /    \
      /      \
     /________\
  速度         大小
(Speed)      (Size)

你最多只能优化两个维度，第三个必然受限。
```

### 推荐的入门模型（按优先级排序）

1. **Qwen2.5-1.5B-Instruct (Q4_K_M)** — 中文最好，~1GB
2. **Llama 3.2 1B-Instruct (Q4_K_M)** — 最小最快，~0.7GB
3. **Gemma 2 2B-Instruct (Q4_K_M)** — 均衡之选，~1.5GB
4. **Phi-3-mini-Instruct (Q4_K_M)** — 推理最强，~2.2GB

## Step 2: 获取量化模型

### 方案 A: 直接下载现成的 GGUF 模型（推荐）

```bash
# HuggingFace 上有大量预量化的 GGUF 模型
# 搜索关键词: "模型名 GGUF"

# 例如下载 Qwen2.5-1.5B 的 Q4 量化版本:
# https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF

# 或使用 huggingface-cli:
pip install huggingface_hub
huggingface-cli download Qwen/Qwen2.5-1.5B-Instruct-GGUF \
    qwen2.5-1.5b-instruct-q4_k_m.gguf \
    --local-dir ./models
```

### 方案 B: 自行量化

```bash
# 1. 安装 llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make

# 2. 下载原始模型
# 从 HuggingFace 下载 safetensors 格式

# 3. 转换为 GGUF
python convert_hf_to_gguf.py /path/to/model --outtype f16

# 4. 量化
./llama-quantize model-f16.gguf model-q4_k_m.gguf Q4_K_M
```

## Step 3: 在 iOS 中集成 llama.cpp

### 3.1 使用 Swift Package Manager

在 Demo 工程中，我们通过 SPM 引入 llama.cpp 的 Swift 绑定：

```
依赖: https://github.com/ggerganov/llama.cpp (swift 分支)
```

### 3.2 模型加载流程

```
App 启动
    │
    ▼
检查本地是否有模型文件
    │
    ├── 有 → 直接加载
    │
    └── 没有 → 下载模型
                 │
                 ▼
           显示下载进度
                 │
                 ▼
           下载完成 → 加载模型
                         │
                         ▼
                    模型加载到内存
                         │
                         ▼
                    准备就绪，可以聊天
```

### 3.3 推理流程

```swift
// 伪代码示意，展示核心流程

func chat(userMessage: String) async -> AsyncStream<String> {
    return AsyncStream { continuation in
        Task {
            // 1. 构建 prompt（使用模型的 chat template）
            let prompt = buildPrompt(
                system: "你是一个友好的AI助手",
                messages: chatHistory + [userMessage]
            )
            
            // 2. Tokenize
            let tokens = tokenize(prompt)
            
            // 3. 记录开始时间（用于 benchmark）
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 4. Prefill（处理 prompt）
            evaluate(tokens: tokens)
            let prefillTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // 5. Decode（逐 token 生成）
            var generatedTokens = 0
            while !shouldStop {
                let nextToken = sampleNextToken()
                let text = detokenize(nextToken)
                
                continuation.yield(text)  // 流式输出
                generatedTokens += 1
                
                if nextToken == eosToken || generatedTokens >= maxTokens {
                    break
                }
            }
            
            // 6. 记录性能指标
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            let tokensPerSecond = Double(generatedTokens) / totalTime
            
            continuation.finish()
        }
    }
}
```

## Step 4: 性能优化

### 内存优化

```
技巧 1: 使用 mmap（内存映射）
- llama.cpp 默认使用 mmap 加载模型
- 不需要把整个模型一次性读入内存
- 操作系统按需加载页面

技巧 2: 控制上下文长度
- n_ctx = 512  → 内存少，但对话受限
- n_ctx = 2048 → 内存适中，推荐
- n_ctx = 4096 → 内存多，长对话

技巧 3: 及时释放
- 对话结束后释放 context
- 切换模型时释放旧模型
```

### 速度优化

```
技巧 1: 选择合适的量化
- Q4_K_M: 速度和质量的最佳平衡
- Q4_0: 更快但质量略差
- Q8_0: 质量好但速度慢

技巧 2: 利用 Metal GPU
- llama.cpp 支持 Metal GPU 加速
- 设置 n_gpu_layers 来控制 GPU 使用

技巧 3: 批量推理
- 设置合适的 n_batch 大小
- 过大浪费内存，过小浪费算力
```

### 发热管理

```swift
// 监控设备温度
class ThermalMonitor {
    func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    @objc func thermalStateChanged() {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            // 正常，全速推理
            break
        case .fair:
            // 略热，可以继续
            break
        case .serious:
            // 很热，降低推理速度
            throttleInference()
        case .critical:
            // 过热，暂停推理
            pauseInference()
        @unknown default:
            break
        }
    }
}
```

## Step 5: Benchmark 方案

### 标准化测试流程

```
Test Suite:
├── Test 1: 模型加载速度
│   └── 从文件到可用状态的时间
├── Test 2: 首 token 延迟 (TTFT)
│   └── 输入 prompt → 第一个 token 输出的时间
├── Test 3: 生成速度 (TPS)
│   └── 每秒生成的 token 数
├── Test 4: 内存占用
│   └── 模型加载后的峰值内存
├── Test 5: 长文本处理
│   └── 不同 prompt 长度的性能变化
└── Test 6: 输出质量
    └── 预定义问题集的回答质量评分
```

### 标准化 Prompt 集

```
简单任务:
- "1+1等于几？"
- "用一句话介绍iOS开发"
- "翻译：Hello World"

中等任务:
- "写一个冒泡排序的Swift代码"
- "解释什么是ARC"
- "总结这段文字的要点：[200字文本]"

困难任务:
- "设计一个iOS App的MVVM架构，包含网络层和持久层"
- "分析这段代码的bug：[复杂代码片段]"
- "写一篇500字的技术博客"
```

## 常见问题 FAQ

### Q: 模型文件放在哪里？
```
推荐: App 的 Documents 目录
原因: 
- 可以通过 iTunes 文件共享访问
- 不会被系统自动清理
- 支持 iCloud 备份（可选关闭）

let modelDir = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask).first!
    .appendingPathComponent("Models")
```

### Q: 模型太大用户不愿下载怎么办？
```
策略:
1. 先提供最小的模型 (如 Qwen2.5-0.5B, ~300MB)
2. 让用户体验后再推荐更大模型
3. 支持 Wi-Fi only 下载
4. 显示清晰的大小信息和预估下载时间
```

### Q: 推理过程中 App 被系统杀死怎么办？
```
策略:
1. 使用 BGProcessingTask 进行后台推理
2. 监控内存水位，主动释放
3. 保存对话上下文，支持恢复
4. 在内存警告时停止推理
```

## 本指南对应的 Demo

所有上述概念都已在 `AIInfraApp/` 中实现为可运行的 Demo，请继续阅读代码。

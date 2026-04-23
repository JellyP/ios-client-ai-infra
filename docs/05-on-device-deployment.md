# 05 - 端侧部署实践：从下载模型到跑起来的全流程

> 前面四篇是理论，这一篇把理论落地到代码。从"选哪个模型"到"推理怎么加速"到"发热怎么管"，每一步都是 iPhone 上端侧 AI 的实战经验。

## 读这篇你能收获什么

- 掌握端侧部署的**完整流程**（选模型 → 下载 → 集成 → 优化）
- 看懂 llama.cpp 的**核心 API**（模型加载、推理、采样）
- 学会**内存管理**（mmap、KV Cache 裁剪、OOM 防护）
- 掌握 **Metal 加速**的开启方法和调优参数
- 知道怎么做**系统化 Benchmark**（公平对比不同模型）
- 学会**发热管理**（ThermalState 监控 + 降级策略）

---

## 一、端侧部署全景

```
┌─────────────────────────────────────────────────────────────────┐
│                     端侧 AI 部署全流程                            │
│                                                                 │
│  Step 1: 选模型                                                  │
│    ├─ 需求分析                                                   │
│    ├─ 设备限制                                                   │
│    └─ 选择参数量 + 量化方案                                        │
│                                                                 │
│  Step 2: 获取 GGUF 文件                                          │
│    ├─ 方案 A: HuggingFace 下载现成的                              │
│    ├─ 方案 B: 自己转换和量化                                      │
│    └─ 文件校验（哈希、大小）                                       │
│                                                                 │
│  Step 3: 集成 llama.cpp                                         │
│    ├─ Swift Package Manager 依赖                                 │
│    ├─ C 桥接层封装                                                │
│    └─ Swift API 设计                                             │
│                                                                 │
│  Step 4: 模型分发                                                │
│    ├─ 内置 vs 按需下载                                            │
│    ├─ 断点续传                                                    │
│    └─ 存储位置和清理                                              │
│                                                                 │
│  Step 5: 运行时优化                                              │
│    ├─ Metal GPU 加速                                             │
│    ├─ KV Cache 管理                                              │
│    ├─ 上下文窗口调优                                              │
│    └─ 内存水位监控                                                │
│                                                                 │
│  Step 6: 质量保证                                                │
│    ├─ Benchmark 方案                                              │
│    ├─ 热管理                                                      │
│    ├─ 电池影响                                                    │
│    └─ 异常处理                                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、Step 1: 选模型

### 2.1 三角约束

```
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

### 2.2 需求驱动的决策

```swift
enum UseCase {
    case keyboardSuggestion     // 键盘预测
    case noteSummary           // 笔记摘要
    case chatAssistant         // 通用对话
    case codeCompletion        // 代码补全
    case photoDescription      // 图片描述
}

extension UseCase {
    var recommendedModel: String {
        switch self {
        case .keyboardSuggestion:
            return "Qwen2.5-0.5B"      // 需要极速响应
        case .noteSummary:
            return "Qwen2.5-1.5B"      // 质量和速度平衡
        case .chatAssistant:
            return "Llama-3.2-3B"      // 对话能力要强
        case .codeCompletion:
            return "Phi-3-mini"        // 推理能力要强
        case .photoDescription:
            return "SmolVLM-500M"      // 多模态
        }
    }
}
```

### 2.3 设备能力判定

```swift
import Foundation

struct DeviceCapability {
    let totalRAM: UInt64  // 总 RAM（字节）
    let modelName: String  // 设备型号
    
    static var current: DeviceCapability {
        var size: size_t = 0
        sysctlbyname("hw.memsize", nil, &size, nil, 0)
        var ram: UInt64 = 0
        sysctlbyname("hw.memsize", &ram, &size, nil, 0)
        
        return DeviceCapability(
            totalRAM: ram,
            modelName: UIDevice.current.modelName
        )
    }
    
    var maxModelSize: UInt64 {
        // 粗略估计：模型 + KV Cache + 系统开销
        // 留出 60% 的 RAM 给系统和其他
        return totalRAM * 40 / 100
    }
    
    var recommendedModels: [String] {
        let maxSizeGB = Double(maxModelSize) / 1_000_000_000
        switch maxSizeGB {
        case ..<1:
            return ["Qwen2.5-0.5B-Q4"]          // 很小的设备
        case 1..<2:
            return ["Qwen2.5-1.5B-Q4"]
        case 2..<3:
            return ["Llama-3.2-3B-Q4", "Phi-3-mini-Q4"]
        default:
            return ["Qwen2.5-7B-Q4"]            // iPad Pro
        }
    }
}
```

---

## 三、Step 2: 获取 GGUF 文件

### 3.1 方案 A: 从 HuggingFace 下载现成的（推荐）

HuggingFace 上有大量预量化好的 GGUF 文件，直接下载就能用。

```swift
// App 内下载实现
class ModelDownloader {
    let urlSession: URLSession
    let fileManager = FileManager.default
    
    func downloadModel(
        repoId: String,           // 例: "Qwen/Qwen2.5-1.5B-Instruct-GGUF"
        fileName: String,         // 例: "qwen2.5-1.5b-instruct-q4_k_m.gguf"
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let url = URL(string: "https://huggingface.co/\(repoId)/resolve/main/\(fileName)")!
        
        // 本地保存路径（Documents 目录）
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsURL.appendingPathComponent("Models")
        try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        let destURL = modelsDir.appendingPathComponent(fileName)
        
        // 已存在则直接返回
        if fileManager.fileExists(atPath: destURL.path) {
            return destURL
        }
        
        // 支持断点续传
        var request = URLRequest(url: url)
        let partialURL = destURL.appendingPathExtension("part")
        if let existingData = try? Data(contentsOf: partialURL) {
            request.setValue("bytes=\(existingData.count)-", forHTTPHeaderField: "Range")
        }
        
        // 下载
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        guard let httpResp = response as? HTTPURLResponse,
              (200...299).contains(httpResp.statusCode) else {
            throw DownloadError.badResponse
        }
        
        let totalBytes = httpResp.expectedContentLength
        var receivedBytes: Int64 = 0
        var buffer = Data()
        
        let handle = try FileHandle(forWritingTo: partialURL)
        defer { try? handle.close() }
        
        for try await byte in asyncBytes {
            buffer.append(byte)
            if buffer.count > 1_000_000 {  // 每 1MB 写一次
                try handle.write(contentsOf: buffer)
                receivedBytes += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                progress(Double(receivedBytes) / Double(totalBytes))
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }
        
        // 完成后重命名
        try fileManager.moveItem(at: partialURL, to: destURL)
        return destURL
    }
}

enum DownloadError: Error {
    case badResponse
    case cancelled
    case insufficientStorage
}
```

### 3.2 存储位置选择

```swift
enum ModelStorage {
    case documents      // Documents 目录
    case caches         // Caches 目录
    case appSupport     // Application Support 目录
    
    var recommendedFor: [String] {
        switch self {
        case .documents:
            return ["用户可见、iCloud 备份（需关闭）", "推荐"]
        case .caches:
            return ["系统可清理，不推荐放模型"]
        case .appSupport:
            return ["系统不可见，也可以"]
        }
    }
}

// 正确做法：Documents + 关闭 iCloud 备份
func getModelPath(fileName: String) throws -> URL {
    let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let modelsDir = docsURL.appendingPathComponent("Models")
    try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
    
    // 关闭 iCloud 备份（避免几 GB 的模型文件被备份到 iCloud）
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var mutableDir = modelsDir
    try mutableDir.setResourceValues(resourceValues)
    
    return modelsDir.appendingPathComponent(fileName)
}
```

### 3.3 文件完整性校验

```swift
// 下载完成后校验 SHA256
func verifyFile(at url: URL, expectedSHA256: String) throws -> Bool {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    let hash = SHA256.hash(data: data)
    let hashString = hash.map { String(format: "%02x", $0) }.joined()
    return hashString == expectedSHA256
}
```

---

## 四、Step 3: 集成 llama.cpp

### 4.1 通过 Swift Package Manager 添加

```swift
// Package.swift
let package = Package(
    name: "MyAIApp",
    dependencies: [
        .package(
            url: "https://github.com/ggerganov/llama.cpp",
            branch: "master"  // 或固定某个 tag
        )
    ],
    targets: [
        .target(
            name: "MyAIApp",
            dependencies: [
                .product(name: "llama", package: "llama.cpp")
            ]
        )
    ]
)
```

### 4.2 核心 API 封装

```swift
import Foundation
import llama

public final class LlamaEngine {
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var batch: llama_batch
    
    private let nCtx: Int32
    private let nBatch: Int32
    
    public init(modelPath: String, contextLength: Int32 = 4096) throws {
        self.nCtx = contextLength
        self.nBatch = 512
        self.batch = llama_batch_init(nBatch, 0, 1)
        
        // 1. 初始化 llama 后端
        llama_backend_init()
        
        // 2. 模型参数
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 999  // 所有层放 GPU（Metal）
        
        // 3. 加载模型文件（使用 mmap，懒加载）
        guard let loadedModel = llama_load_model_from_file(modelPath, modelParams) else {
            throw LlamaError.modelLoadFailed
        }
        self.model = loadedModel
        self.vocab = llama_model_get_vocab(loadedModel)
        
        // 4. 创建推理上下文
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(nCtx)
        ctxParams.n_batch = UInt32(nBatch)
        ctxParams.n_threads = Int32(ProcessInfo.processInfo.activeProcessorCount - 1)
        ctxParams.n_threads_batch = ctxParams.n_threads
        
        guard let ctx = llama_new_context_with_model(loadedModel, ctxParams) else {
            llama_free_model(loadedModel)
            throw LlamaError.contextCreationFailed
        }
        self.context = ctx
    }
    
    deinit {
        llama_batch_free(batch)
        if let ctx = context { llama_free(ctx) }
        if let m = model { llama_free_model(m) }
        llama_backend_free()
    }
}

enum LlamaError: Error {
    case modelLoadFailed
    case contextCreationFailed
    case tokenizeFailed
    case decodeFailed
}
```

### 4.3 Tokenize：文本 → token 数组

```swift
extension LlamaEngine {
    func tokenize(_ text: String, addBos: Bool = true) throws -> [llama_token] {
        guard let vocab = vocab else { throw LlamaError.tokenizeFailed }
        
        let cString = text.cString(using: .utf8)!
        let textLen = Int32(cString.count - 1)
        
        // 预估最多的 token 数（字符数的 2 倍足够）
        let maxTokens = Int32(text.count * 2)
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        
        let actualCount = llama_tokenize(
            vocab,
            cString, textLen,
            &tokens, maxTokens,
            addBos,   // 是否添加 BOS 特殊 token
            false     // 是否解析特殊 token
        )
        
        guard actualCount > 0 else {
            throw LlamaError.tokenizeFailed
        }
        
        return Array(tokens.prefix(Int(actualCount)))
    }
    
    func detokenize(_ token: llama_token) -> String {
        guard let vocab = vocab else { return "" }
        
        var buf = [CChar](repeating: 0, count: 128)
        let len = llama_token_to_piece(vocab, token, &buf, 128, 0, false)
        guard len > 0 else { return "" }
        
        return String(cString: buf)
    }
}
```

### 4.4 Prefill + Decode 完整流程

```swift
extension LlamaEngine {
    func generate(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topK: Int32 = 40,
        topP: Float = 0.9
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let ctx = self.context, let vocab = self.vocab else {
                        throw LlamaError.contextCreationFailed
                    }
                    
                    // 1. Tokenize prompt
                    let promptTokens = try self.tokenize(prompt)
                    
                    // 2. 清空之前的 KV cache
                    llama_kv_cache_clear(ctx)
                    
                    // 3. Prefill：处理 prompt
                    try self.prefill(tokens: promptTokens)
                    
                    // 4. Decode：生成新 token
                    var nCur = Int32(promptTokens.count)
                    let eosToken = llama_vocab_eos(vocab)
                    
                    // 创建采样器
                    var sparams = llama_sampler_chain_default_params()
                    let sampler = llama_sampler_chain_init(sparams)
                    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(topK))
                    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1))
                    llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature))
                    llama_sampler_chain_add(sampler, llama_sampler_init_dist(42))
                    defer { llama_sampler_free(sampler) }
                    
                    for _ in 0..<maxTokens {
                        // 采样下一个 token
                        let nextToken = llama_sampler_sample(sampler, ctx, -1)
                        
                        // 遇到 EOS 停止
                        if nextToken == eosToken {
                            break
                        }
                        
                        // 流式输出
                        let piece = self.detokenize(nextToken)
                        continuation.yield(piece)
                        
                        // 把新 token 喂回模型（更新 KV cache）
                        try self.decodeSingle(token: nextToken, position: nCur)
                        nCur += 1
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func prefill(tokens: [llama_token]) throws {
        guard let ctx = context else { throw LlamaError.decodeFailed }
        
        // 清空 batch
        batch.n_tokens = 0
        
        // 填入所有 prompt token
        for (i, token) in tokens.enumerated() {
            let pos = Int32(i)
            batch.token[Int(batch.n_tokens)] = token
            batch.pos[Int(batch.n_tokens)] = pos
            batch.n_seq_id[Int(batch.n_tokens)] = 1
            batch.seq_id[Int(batch.n_tokens)]![0] = 0
            batch.logits[Int(batch.n_tokens)] = (i == tokens.count - 1) ? 1 : 0
            batch.n_tokens += 1
        }
        
        guard llama_decode(ctx, batch) == 0 else {
            throw LlamaError.decodeFailed
        }
    }
    
    private func decodeSingle(token: llama_token, position: Int32) throws {
        guard let ctx = context else { throw LlamaError.decodeFailed }
        
        batch.n_tokens = 1
        batch.token[0] = token
        batch.pos[0] = position
        batch.n_seq_id[0] = 1
        batch.seq_id[0]![0] = 0
        batch.logits[0] = 1
        
        guard llama_decode(ctx, batch) == 0 else {
            throw LlamaError.decodeFailed
        }
    }
}
```

### 4.5 支持 Chat Template

```swift
extension LlamaEngine {
    func applyChatTemplate(
        messages: [(role: String, content: String)],
        addGenerationPrompt: Bool = true
    ) -> String {
        // 方案 1: 用 llama.cpp 内置的 chat template 解析
        guard let model = model else { return "" }
        
        var chatMessages = messages.map { msg in
            var lMsg = llama_chat_message()
            lMsg.role = strdup(msg.role)
            lMsg.content = strdup(msg.content)
            return lMsg
        }
        defer {
            chatMessages.forEach {
                free(UnsafeMutableRawPointer(mutating: $0.role))
                free(UnsafeMutableRawPointer(mutating: $0.content))
            }
        }
        
        var buf = [CChar](repeating: 0, count: 8192)
        let len = llama_chat_apply_template(
            nil,  // 用模型内置的 template
            &chatMessages,
            chatMessages.count,
            addGenerationPrompt,
            &buf,
            Int32(buf.count)
        )
        
        guard len > 0 else { return "" }
        return String(cString: buf)
    }
}

// 使用
let prompt = engine.applyChatTemplate(messages: [
    ("system", "You are a helpful assistant."),
    ("user", "什么是 iOS？")
])
```

---

## 五、Step 4: 模型分发策略

### 5.1 三种分发模式

```
模式 A: App 内置模型（随 App 包发布）
  ✅ 首次打开就能用
  ❌ App 包巨大（1-3 GB）
  ❌ App Store 审核困难
  ❌ 更新模型要更新 App
  
  适用：嵌入式小模型（<100MB）

模式 B: 首次启动下载
  ✅ App 包体积小
  ✅ 可以更新模型不更新 App
  ❌ 首次体验差（要等下载）
  ❌ 流量成本
  
  适用：大多数场景

模式 C: 按需下载（用户触发）
  ✅ 用户知情
  ✅ 可以提供多个模型选择
  ❌ 用户可能不下载
  
  适用：可选功能
```

### 5.2 清理策略

```swift
class ModelStorageManager {
    let maxCacheSize: UInt64 = 4 * 1024 * 1024 * 1024  // 最多 4 GB
    
    func getCachedSize() -> UInt64 {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsURL.appendingPathComponent("Models")
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: modelsDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return 0 }
        
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + UInt64(size)
        }
    }
    
    func cleanupIfNeeded() {
        let current = getCachedSize()
        guard current > maxCacheSize else { return }
        
        // LRU 策略：删除最久未访问的模型
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsURL.appendingPathComponent("Models")
        
        let files = (try? FileManager.default.contentsOfDirectory(
            at: modelsDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey]
        )) ?? []
        
        let sorted = files.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            return aDate < bDate  // 最旧的在前
        }
        
        var freed: UInt64 = 0
        for file in sorted {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try? FileManager.default.removeItem(at: file)
            freed += UInt64(size)
            if current - freed < maxCacheSize { break }
        }
    }
}
```

---

## 六、Step 5: 运行时优化

### 6.1 Metal GPU 加速

```swift
var modelParams = llama_model_default_params()

// 关键参数：多少层放 GPU
modelParams.n_gpu_layers = 999  // 所有层都放 GPU（推荐）

// 可选值:
//   0    → 完全 CPU 推理（最慢，最省内存）
//   N    → 前 N 层放 GPU
//   999  → 所有层放 GPU（最快，内存需求最高）

// iPhone 上 Metal 加速通常快 3-5 倍
```

**注意事项**：

- Metal 会占用 GPU 内存（和系统内存共享，UMA 架构）
- 如果 `n_gpu_layers` 太大导致 OOM，会 crash
- 可以通过减少 `n_gpu_layers` 让部分层回退 CPU，以降低内存

### 6.2 KV Cache 管理

```swift
// 场景：长对话可能爆内存，需要裁剪 KV Cache

class ChatContext {
    let engine: LlamaEngine
    var conversationTokens: [llama_token] = []
    let maxContextTokens: Int = 3500  // 留一些给生成
    
    func addUserMessage(_ text: String) throws {
        let newTokens = try engine.tokenize(text, addBos: false)
        
        // 检查是否会溢出
        if conversationTokens.count + newTokens.count > maxContextTokens {
            // 裁剪策略：保留前 N 个（system prompt）+ 最近的 M 个
            let keepFirst = 100
            let keepLast = 2000
            
            let kept = Array(conversationTokens.prefix(keepFirst)) +
                       Array(conversationTokens.suffix(keepLast))
            
            conversationTokens = kept
            
            // 清空 KV cache 并重新 prefill
            engine.clearKVCache()
            try engine.prefill(tokens: conversationTokens)
        }
        
        conversationTokens.append(contentsOf: newTokens)
    }
}
```

### 6.3 线程数调优

```swift
var ctxParams = llama_context_default_params()

let coreCount = ProcessInfo.processInfo.activeProcessorCount
// iPhone 15 Pro: 6 核（2 性能 + 4 效率）

// 经验值:
ctxParams.n_threads = Int32(coreCount - 1)       // 留 1 核给系统
ctxParams.n_threads_batch = Int32(coreCount - 1) // Prefill 时的线程数

// ⚠️ 超线程(线程 > 核心数) 不会加快，反而降低
// ⚠️ iOS 上后台运行时线程会被降频
```

### 6.4 内存监控

```swift
class MemoryMonitor {
    static func currentFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
    
    static func observeMemoryWarning(handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in handler() }
    }
}

// 使用
MemoryMonitor.observeMemoryWarning {
    // 收到内存警告：清空 KV cache、释放非关键资源
    engine.clearKVCache()
}
```

---

## 七、Step 6: Benchmark 方案

### 7.1 标准指标

```swift
struct BenchmarkMetrics {
    // 基础信息
    let modelName: String
    let modelFileSize: UInt64           // 文件大小（bytes）
    let quantization: String            // 量化方案
    let deviceModel: String             // 设备型号
    let iosVersion: String
    
    // 时间指标
    let loadTime: TimeInterval          // 模型加载时间
    let firstTokenLatency: TimeInterval // 首 token 延迟 (TTFT)
    let totalTime: TimeInterval         // 总推理时间
    
    // 速度指标
    let prefillTokensPerSecond: Double  // Prefill 速度
    let decodeTokensPerSecond: Double   // Decode 速度
    
    // 资源指标
    let peakMemoryFootprint: UInt64     // 峰值内存
    let thermalStateChanges: [ProcessInfo.ThermalState]  // 温度变化
    
    // 输出指标
    let promptTokens: Int
    let outputTokens: Int
    let outputText: String
}
```

### 7.2 标准 Prompt 集

```swift
struct BenchmarkSuite {
    static let simple = [
        "1+1 等于几？",
        "用一句话介绍自己",
        "翻译：Hello, World",
    ]
    
    static let medium = [
        "写一个冒泡排序的 Swift 代码",
        "解释什么是 iOS 的 ARC 内存管理",
        "列出 5 种常见的设计模式",
    ]
    
    static let complex = [
        """
        请分析下面代码的潜在 bug 并提出修复方案：
        [粘贴 200 行 Swift 代码]
        """,
        "设计一个支持多租户、高并发的消息推送系统",
    ]
    
    static let chinese = [
        "鲁迅和周树人是什么关系？",
        "写一首关于程序员的打油诗",
        "翻译以下古文：学而时习之，不亦说乎",
    ]
}
```

### 7.3 完整 Benchmark 实现

```swift
class Benchmarker {
    let engine: LlamaEngine
    let modelName: String
    
    func runFullBenchmark() async throws -> [BenchmarkMetrics] {
        var results: [BenchmarkMetrics] = []
        
        // 热身：避免首次开销影响数据
        _ = try await engine.generate(prompt: "hello")
        
        // 测试集
        let allPrompts = BenchmarkSuite.simple +
                         BenchmarkSuite.medium +
                         BenchmarkSuite.chinese
        
        for prompt in allPrompts {
            let result = try await runSingle(prompt: prompt)
            results.append(result)
            
            // 散热间隔
            if ProcessInfo.processInfo.thermalState != .nominal {
                try? await Task.sleep(nanoseconds: 5_000_000_000)  // 等 5 秒
            }
        }
        
        return results
    }
    
    func runSingle(prompt: String) async throws -> BenchmarkMetrics {
        let formatted = engine.applyChatTemplate(messages: [("user", prompt)])
        let promptTokens = try engine.tokenize(formatted)
        
        let prefillStart = CFAbsoluteTimeGetCurrent()
        try engine.clearKVCacheAndPrefill(tokens: promptTokens)
        let prefillTime = CFAbsoluteTimeGetCurrent() - prefillStart
        
        let decodeStart = CFAbsoluteTimeGetCurrent()
        var firstTokenTime: TimeInterval?
        var output = ""
        var tokenCount = 0
        
        for try await token in engine.decodeStream() {
            if firstTokenTime == nil {
                firstTokenTime = CFAbsoluteTimeGetCurrent() - decodeStart
            }
            output += token
            tokenCount += 1
            if tokenCount >= 256 { break }  // 限制长度
        }
        
        let decodeTime = CFAbsoluteTimeGetCurrent() - decodeStart
        
        return BenchmarkMetrics(
            modelName: modelName,
            modelFileSize: /* ... */ 0,
            quantization: "Q4_K_M",
            deviceModel: UIDevice.current.modelName,
            iosVersion: UIDevice.current.systemVersion,
            loadTime: 0,  // 另外测
            firstTokenLatency: prefillTime + (firstTokenTime ?? 0),
            totalTime: prefillTime + decodeTime,
            prefillTokensPerSecond: Double(promptTokens.count) / prefillTime,
            decodeTokensPerSecond: Double(tokenCount) / decodeTime,
            peakMemoryFootprint: MemoryMonitor.currentFootprint(),
            thermalStateChanges: [],
            promptTokens: promptTokens.count,
            outputTokens: tokenCount,
            outputText: output
        )
    }
}
```

### 7.4 公平对比的注意事项

```
测试时要控制的变量:
  ✅ 同一台设备
  ✅ 同样的 prompt（用标准集）
  ✅ 同样的采样参数（Temperature、Top-K、Top-P）
  ✅ 同样的上下文长度（n_ctx）
  ✅ 同样的热状态（测试前让手机冷却）
  ✅ 同样的电量状态（80%+，充电中）
  ✅ 飞行模式，关闭其他 App
  
容易忽视的影响:
  ⚠️ 系统进入后台会大幅降速
  ⚠️ 低电量模式会限制 CPU/GPU
  ⚠️ iOS 15+ 的 Low Power Mode 影响 Metal
  ⚠️ 连续测试会因为发热降频
```

---

## 八、发热管理：端侧 AI 的隐藏杀手

### 8.1 ThermalState 监控

```swift
class ThermalMonitor {
    var currentState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
    
    func startMonitoring(onChange: @escaping (ProcessInfo.ThermalState) -> Void) {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            onChange(self.currentState)
        }
    }
}

// 使用
let monitor = ThermalMonitor()
monitor.startMonitoring { state in
    switch state {
    case .nominal:
        // 正常
        break
    case .fair:
        // 微热，不做动作
        break
    case .serious:
        // 过热，降级：用更小模型 or 暂停推理
        engine.switchToSmallerModel()
    case .critical:
        // 严重过热，必须停止
        engine.pauseInference()
        showAlert("设备过热，暂停 AI 功能")
    @unknown default:
        break
    }
}
```

### 8.2 降级策略

```swift
class AdaptiveInference {
    let heavyModel: LlamaEngine   // 3B 模型
    let lightModel: LlamaEngine   // 0.5B 模型
    let cloudProvider: AIProvider  // 云端 API
    
    func chat(messages: [Message]) -> AsyncThrowingStream<String, Error> {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal, .fair:
            return heavyModel.chat(messages: messages)   // 全力推理
            
        case .serious:
            // 退到小模型
            return lightModel.chat(messages: messages)
            
        case .critical:
            // 退到云端
            return cloudProvider.chat(messages: messages)
            
        @unknown default:
            return heavyModel.chat(messages: messages)
        }
    }
}
```

### 8.3 连续推理的散热节奏

```swift
// 批量分类场景下，主动插入冷却间隔
func classifyBatch(_ items: [String]) async throws -> [String] {
    var results: [String] = []
    
    for (i, item) in items.enumerated() {
        let result = try await engine.classify(item)
        results.append(result)
        
        // 每 10 次检查一次温度
        if i % 10 == 9 {
            let state = ProcessInfo.processInfo.thermalState
            switch state {
            case .serious:
                // 过热，休息 30 秒
                try await Task.sleep(nanoseconds: 30_000_000_000)
            case .critical:
                // 严重过热，终止
                throw InferenceError.thermalThrottled
            default:
                // 正常，短暂间隔
                try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
            }
        }
    }
    
    return results
}
```

---

## 九、异常处理清单

### 9.1 常见失败场景

```swift
enum InferenceFailure {
    case outOfMemory               // 内存不足
    case modelCorrupted            // 模型文件损坏
    case unsupportedArchitecture   // llama.cpp 不支持该模型
    case contextOverflow           // 输入超出上下文窗口
    case thermalThrottled          // 设备过热
    case backgroundExecution       // App 进入后台
}
```

### 9.2 OOM 防护

```swift
// App 进入后台时主动释放资源
NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification,
    object: nil,
    queue: .main
) { _ in
    // 卸载大模型
    engine.unload()
}

// 内存警告
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    // 清 KV cache
    engine.clearKVCache()
}
```

### 9.3 推理中断

```swift
class CancellableInference {
    var currentTask: Task<Void, Error>?
    
    func startChat(messages: [Message]) {
        currentTask?.cancel()
        
        currentTask = Task {
            for try await token in engine.chat(messages: messages) {
                // 检查是否被取消
                try Task.checkCancellation()
                await renderToken(token)
            }
        }
    }
    
    func stop() {
        currentTask?.cancel()
        currentTask = nil
    }
}
```

---

## 十、常见问题 FAQ

### Q1: 为什么 iPhone 运行比想象的慢？

```
可能的原因:
  1. 没开 Metal 加速 (n_gpu_layers = 0)
  2. 模型量化太保守 (用了 FP16 而不是 Q4)
  3. 上下文太长 (n_ctx = 8192 导致 KV cache 巨大)
  4. 低电量模式
  5. 设备温度过高已降频
  6. 后台运行被系统限频
```

### Q2: 怎么在 SwiftUI 里做流式显示？

```swift
struct ChatView: View {
    @State private var streamingText = ""
    @StateObject var viewModel = ChatViewModel()
    
    var body: some View {
        VStack {
            Text(streamingText)
                .animation(.default, value: streamingText)
            
            Button("发送") {
                Task {
                    streamingText = ""
                    for try await token in viewModel.engine.generate(prompt: "你好") {
                        await MainActor.run {
                            streamingText += token
                        }
                    }
                }
            }
        }
    }
}
```

### Q3: 模型质量不行怎么办？

```
checklist:
  ☐ 是否用了正确的 chat template? (90% 的问题出在这)
  ☐ 采样参数是否合理? (温度 0.7, Top-P 0.9)
  ☐ 量化是否过度? (Q2 明显不如 Q4)
  ☐ 模型本身能力是否够? (1.5B 别指望写长文)
  ☐ prompt 是否给了足够的上下文/例子?
```

### Q4: 输出中英文乱码？

```
原因：token 可能是半个 UTF-8 字符
解决：累积字节直到能解析出完整字符

class UTF8StreamDecoder {
    private var buffer = Data()
    
    func decode(_ bytes: [UInt8]) -> String? {
        buffer.append(contentsOf: bytes)
        
        // 尝试解析
        if let str = String(data: buffer, encoding: .utf8) {
            buffer.removeAll()
            return str
        }
        
        // 不完整，等更多字节
        return nil
    }
}
```

---

## 十一、这一篇的核心收获

1. **端侧部署是系统工程**：模型只是开始，还要考虑下载、存储、内存、发热、电池
2. **GGUF + llama.cpp 是入门首选**：生态最好，社区最活跃
3. **Metal 加速必开**：`n_gpu_layers = 999`，速度快 3-5 倍
4. **KV Cache 要管理**：长对话必须有裁剪策略，否则爆内存
5. **Chat Template 不能省**：错了就乱码/胡言乱语
6. **Benchmark 要系统化**：标准 prompt 集 + 控制变量 + 公平对比
7. **发热是隐藏杀手**：ThermalState 监控 + 降级策略不可少
8. **异常处理要充分**：OOM、中断、后台、温度、网络，每一样都要考虑

---

## 系列总结

恭喜！你已经读完了整个系列：

1. [01 - AI 基础](01-ai-basics.md) - 大模型是什么
2. [02 - 云端 vs 端侧](02-model-categories.md) - 两种部署的深度对比
3. [03 - Dense 模型](03-text-models.md) - Transformer 架构解析
4. [04 - MoE 模型](04-moe-models.md) - 稀疏激活的魔法
5. [05 - 端侧部署实践](05-on-device-deployment.md) - 实战指南 ← 你在这里
6. [06 - MoE 图片识别](06-moe-image-classification.md) - 多模态深入

**你现在应该能**：

- 理解大模型从 token 到 token 的完整数据流
- 看懂 Transformer/MoE 每一层在做什么
- 在 iPhone 上集成 llama.cpp 跑起任意 GGUF 模型
- 做系统化的性能评估
- 设计云端 + 端侧的混合架构

**下一步建议**：

- 在本项目 `AIInfraApp/` 里跑通完整 Demo
- 对比不同模型的 Benchmark 数据
- 尝试把自己的 App 场景落地到端侧 AI
- 关注 Apple Intelligence 和 MLX 的最新动态

端侧 AI 是未来 3 年客户端开发最激动人心的方向之一，你已经站在了起跑线上。

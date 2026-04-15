# iOS Client AI Infra - 字符编码问题深度分析

> 专注于 llama.cpp 集成中可能导致乱码的问题和解决方案

## 问题概述

当前工程中，端侧模型推理通过 llama.cpp 框架实现。在 token 生成和转换为可显示文本的过程中，存在以下几个关键的编码问题：

1. **CChar → UInt8 的位转换问题**
2. **UTF-8 多字节字符在 token 边界的断裂问题**
3. **残留字节的处理问题**
4. **模型内置 Chat Template 与手动 Gemma 4 格式冲突问题**

---

## 1. CChar 位转换问题 (第 343-352 行)

### 问题代码
```swift
private func tokenToBytes(token: llama_token) -> [UInt8] {
    guard let vocab = model.map({ llama_model_get_vocab($0) }) else { return [] }

    var buf = [CChar](repeating: 0, count: 256)
    let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, true)
    if n > 0 {
        return (0..<Int(n)).map { UInt8(bitPattern: buf[$0]) }  // ⚠️ 问题行
    }
    return []
}
```

### 问题分析

**CChar 的定义**:
- `CChar` 是 `Int8` 的别名（有符号整数）
- 取值范围: -128 ~ 127

**UInt8 的定义**:
- `UInt8` 是无符号整数
- 取值范围: 0 ~ 255

**位转换的问题**:
```swift
// 示例：llama.cpp 返回的 UTF-8 字节序列
// "你" 的 UTF-8 编码: E4 BD A0 (三个字节)

// 在 C 中，这些字节被解释为 CChar (Int8):
let buf: [CChar] = [-28, -67, -96]  // 0xE4, 0xBD, 0xA0 in signed form

// 使用 bitPattern 转换
let result = buf.map { UInt8(bitPattern: $0) }
// result: [228, 189, 160]  // 正确：0xE4 = 228, 0xBD = 189, 0xA0 = 160
```

**实际上**，`UInt8(bitPattern: CChar)` 在大多数情况下是**正确的**，因为它保留了位模式。但存在以下问题：

1. **符号扩展问题**: 如果中间过程涉及 `Int` 转换，可能导致符号扩展
2. **平台差异**: 在某些编译器或平台上，行为可能不同

### 更好的方法

```swift
// 方法 1: 直接使用 UInt8 的初始化器
private func tokenToBytes(token: llama_token) -> [UInt8] {
    guard let vocab = model.map({ llama_model_get_vocab($0) }) else { return [] }

    var buf = [UInt8](repeating: 0, count: 256)  // ✅ 直接用 UInt8
    let n = llama_token_to_piece(vocab, token, 
                                 UnsafeMutableRawPointer(&buf).assumingMemoryBound(to: CChar.self), 
                                 Int32(buf.count), 0, true)
    if n > 0 {
        return Array(buf.prefix(Int(n)))  // ✅ 直接使用
    }
    return []
}

// 方法 2: 使用 Data 包装（推荐）
private func tokenToBytes(token: llama_token) -> [UInt8] {
    guard let vocab = model.map({ llama_model_get_vocab($0) }) else { return [] }

    var buf = [CChar](repeating: 0, count: 256)
    let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, true)
    if n > 0 {
        // ✅ 使用 Data 的初始化器，会正确处理位转换
        let data = Data(bytes: buf, count: Int(n))
        return [UInt8](data)
    }
    return []
}

// 方法 3: 使用 withUnsafeBytes（最安全）
private func tokenToBytes(token: llama_token) -> [UInt8] {
    guard let vocab = model.map({ llama_model_get_vocab($0) }) else { return [] }

    var buf = [CChar](repeating: 0, count: 256)
    let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, true)
    if n > 0 {
        return buf.withUnsafeBytes { buffer in
            Array(buffer.prefix(Int(n)).map { $0 })
        }
    }
    return []
}
```

---

## 2. UTF-8 多字节字符边界问题 (第 181-191 行)

### 问题代码
```swift
// Decode 循环中的 token 处理
while generatedCount < maxTokens && !isCancelled() {
    let newToken = llama_sampler_sample(sampler, context, -1)
    // ... 其他处理 ...

    // ⚠️ 问题区域：UTF-8 缓冲处理
    let piece = tokenToBytes(token: newToken)
    if !piece.isEmpty {
        utf8Buffer.append(contentsOf: piece)
        if let text = String(data: utf8Buffer, encoding: .utf8) {
            if !text.isEmpty {
                onToken(text)
            }
            utf8Buffer.removeAll()
        }
        // ⚠️ 如果上面的 if let 不成立，utf8Buffer 保留
        // 继续累积可能导致越来越大的缓冲
    }
}
```

### 问题详解

**UTF-8 多字节字符的结构**:
```
范围           字节数    字节格式
U+0000-U+007F    1      0xxxxxxx
U+0080-U+07FF    2      110xxxxx 10xxxxxx
U+0800-U+FFFF    3      1110xxxx 10xxxxxx 10xxxxxx
U+10000-U+10FFFF 4      11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
```

**示例：中文字符 "你" (U+4F60)**
- UTF-8 编码: `E4 BD A0` (3 字节)
- 如果在第一个和第二个字节之间被 token 边界分割：
  - Token 1 返回: `[0xE4]` (首字节)
  - Token 2 返回: `[0xBD, 0xA0]` (续字节)

**当前代码的问题**:
1. 累积后 `[0xE4]` 试图解码为 UTF-8 → 失败（不完整）
2. `utf8Buffer` 仍保留 `[0xE4]`
3. Token 2 来临，累积后 `[0xE4, 0xBD, 0xA0]` → 成功解码为 "你"
4. **看起来正常**

**潜在问题场景**:
- 如果 token 边界在 4 字节字符内部，可能需要 4 个 token 才能拼成一个字符
- 如果 token 返回的字节不完整，`String(data:encoding:)` 会返回 `nil`，导致缓冲堆积
- 缓冲堆积过大可能导致内存问题或死锁

### 更好的解决方案

#### 方案 1: 使用 Swift 的 Unicode Scalar 处理（推荐）

```swift
import Foundation

class UTF8StreamDecoder {
    private var buffer = Data()
    
    /// 添加字节块并尝试解码有效的 UTF-8 字符串
    /// 返回成功解码的字符串，残留字节保留在 buffer 中
    func decode(_ bytes: [UInt8]) -> String {
        buffer.append(contentsOf: bytes)
        
        // 尝试从 buffer 的起始位置找到完整的 UTF-8 字符
        var validEnd = 0
        var index = buffer.startIndex
        
        while index < buffer.endIndex {
            let byte = buffer[index]
            let charLen: Int
            
            // 确定此字符需要多少个字节
            if (byte & 0x80) == 0 {
                charLen = 1
            } else if (byte & 0xE0) == 0xC0 {
                charLen = 2
            } else if (byte & 0xF0) == 0xE0 {
                charLen = 3
            } else if (byte & 0xF8) == 0xF0 {
                charLen = 4
            } else {
                // 无效的 UTF-8 序列，跳过此字节
                index = buffer.index(after: index)
                continue
            }
            
            // 检查是否有足够的字节
            let nextIndex = buffer.index(index, offsetBy: charLen, limitedBy: buffer.endIndex) ?? buffer.endIndex
            if nextIndex > buffer.endIndex {
                break  // 不完整的字符
            }
            
            validEnd = buffer.distance(from: buffer.startIndex, to: nextIndex)
            index = nextIndex
        }
        
        // 解码有效部分
        let validData = buffer.subdata(in: buffer.startIndex..<buffer.index(buffer.startIndex, offsetBy: validEnd))
        let result = String(data: validData, encoding: .utf8) ?? ""
        
        // 保留残留字节
        buffer = buffer.subdata(in: buffer.index(buffer.startIndex, offsetBy: validEnd)..<buffer.endIndex)
        
        return result
    }
    
    /// 获取缓冲中的残留字节
    func flush() -> String {
        if buffer.isEmpty {
            return ""
        }
        // 尝试解码残留字节，即使不完整
        let result = String(data: buffer, encoding: .utf8) ?? ""
        buffer.removeAll()
        return result
    }
}

// 在 LlamaEngine 中使用
var utf8Decoder = UTF8StreamDecoder()

// 在 decode 循环中
while generatedCount < maxTokens && !isCancelled() {
    let newToken = llama_sampler_sample(sampler, context, -1)
    // ...
    
    let piece = tokenToBytes(token: newToken)
    if !piece.isEmpty {
        let text = utf8Decoder.decode(piece)
        if !text.isEmpty {
            onToken(text)
        }
    }
}

// 最后处理残留
if let remaining = utf8Decoder.flush(), !remaining.isEmpty {
    onToken(remaining)
}
```

#### 方案 2: 使用 Foundation 的 Transcoder

```swift
import Foundation

class UTF8StreamDecoder {
    private var buffer = Data()
    
    func decode(_ bytes: [UInt8]) -> String {
        buffer.append(contentsOf: bytes)
        
        // 使用 String 的自动修复 UTF-8
        // 但这会丢弃无效字节，可能不是最好的选择
        let decoded = String(decoding: buffer, as: UTF8.self)
        
        // 重新编码以确定消耗了多少字节
        if let encodedAgain = decoded.data(using: .utf8) {
            if encodedAgain.count < buffer.count {
                // 有残留字节
                buffer = buffer.subdata(in: encodedAgain.count..<buffer.count)
            } else {
                buffer.removeAll()
            }
        }
        
        return decoded
    }
}
```

#### 方案 3: 直接处理 UTF-8 状态机（最控制但也最复杂）

```swift
class UTF8StateMachine {
    enum State {
        case ready
        case waiting(byteCount: Int, accumulator: UInt32)
    }
    
    private var state: State = .ready
    private var result = ""
    
    func feed(_ bytes: [UInt8]) -> String {
        for byte in bytes {
            switch state {
            case .ready:
                if (byte & 0x80) == 0 {
                    // 单字节 ASCII
                    result.append(Character(UnicodeScalar(byte)))
                } else if (byte & 0xE0) == 0xC0 {
                    // 2 字节字符首字节
                    state = .waiting(byteCount: 1, accumulator: UInt32(byte & 0x1F))
                } else if (byte & 0xF0) == 0xE0 {
                    // 3 字节字符首字节
                    state = .waiting(byteCount: 2, accumulator: UInt32(byte & 0x0F))
                } else if (byte & 0xF8) == 0xF0 {
                    // 4 字节字符首字节
                    state = .waiting(byteCount: 3, accumulator: UInt32(byte & 0x07))
                }
                
            case .waiting(let byteCount, let accumulator):
                if (byte & 0xC0) == 0x80 {
                    // 续字节
                    let newAccumulator = (accumulator << 6) | UInt32(byte & 0x3F)
                    if byteCount > 1 {
                        state = .waiting(byteCount: byteCount - 1, accumulator: newAccumulator)
                    } else {
                        // 字符完成
                        if let scalar = UnicodeScalar(newAccumulator) {
                            result.append(Character(scalar))
                        }
                        state = .ready
                    }
                } else {
                    // 无效序列，重置
                    state = .ready
                }
            }
        }
        
        let temp = result
        result = ""
        return temp
    }
    
    func flush() -> String {
        let temp = result
        result = ""
        state = .ready
        return temp
    }
}
```

---

## 3. 残留字节处理问题 (第 202-207 行)

### 问题代码
```swift
// 刷出残留字节
if !utf8Buffer.isEmpty {
    if let text = String(data: utf8Buffer, encoding: .utf8), !text.isEmpty {
        onToken(text)
    }
    // ⚠️ 问题：如果解码失败，这些字节就被无声丢弃了
}
```

### 问题分析

**情况 1: 中文字符被切割**
```
utf8Buffer 包含: [0xE4, 0xBD]  (不完整的"你"字的前两字节)
String(data: utf8Buffer, encoding: .utf8) 返回 nil
结果: 信息丢失
```

**情况 2: Emoji 被切割**
```
utf8Buffer 包含: [0xF0, 0x9F]  (不完整的 emoji)
String(data: utf8Buffer, encoding: .utf8) 返回 nil
结果: 信息丢失
```

### 解决方案

```swift
// ✅ 改进方案：保存残留字节到日志或替代字符
if !utf8Buffer.isEmpty {
    // 选项 1: 强制使用替代字符
    let text = String(decoding: utf8Buffer, as: UTF8.self)
    if !text.isEmpty {
        onToken(text)
    }
    // 注意：String(decoding:as:) 会用替代字符替换无效 UTF-8
    
    // 选项 2: 记录错误日志
    if let decodedText = String(data: utf8Buffer, encoding: .utf8) {
        onToken(decodedText)
    } else {
        print("[LlamaEngine] 警告：无法解码残留字节: \(utf8Buffer.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
}
```

---

## 4. Chat Template 问题

### 当前问题代码 (第 214-286 行)

```swift
private func applyChatTemplate(messages: [(role: String, content: String)]) -> String {
    guard let model else { return "" }

    // ... 构建 llama_chat_message 数组 ...

    var buf = [CChar](repeating: 0, count: 32768)

    // 1. 尝试模型内置 template
    let modelTmpl = llama_model_chat_template(model, nil)
    if let r = tryTemplate(modelTmpl, label: "model-builtin") {
        return r
    }

    // 2. Gemma 4 手动格式
    print("[LlamaEngine] 使用 Gemma 4 格式构造 prompt")
    var prompt = ""
    for msg in processedMessages {
        switch msg.role {
        case "user":
            prompt += "<|turn>user\n\(msg.content)<turn|>\n"
        case "assistant", "model":
            prompt += "<|turn>model\n\(msg.content)<turn|>\n"
        default:
            prompt += "<|turn>user\n\(msg.content)<turn|>\n"
        }
    }
    prompt += "<|turn>model\n"
    return prompt
}
```

### 问题分析

**问题 1: 编码不匹配**
- Gemma 4 格式中的 `<|turn>` 标记可能不被分词器正确识别
- 手动构造的格式可能与模型训练时的格式不同

**问题 2: Content 中的特殊字符**
- 如果 `msg.content` 包含 `\n` 或其他控制字符，格式可能被破坏
- 中文等非 ASCII 字符的处理需要验证

### 改进方案

```swift
private func applyChatTemplate(messages: [(role: String, content: String)]) -> String {
    guard let model else { return "" }

    // ... 预处理 ...

    var buf = [CChar](repeating: 0, count: 32768)

    // 1. 尝试模型内置 template
    let modelTmpl = llama_model_chat_template(model, nil)
    if let r = tryTemplate(modelTmpl, label: "model-builtin") {
        return r
    }

    // 2. 针对不同模型的手动格式处理
    let modelFamily = String(cString: llama_model_get_arch(model))
    
    let prompt: String
    switch modelFamily.lowercased() {
    case _ where modelFamily.contains("gemma"):
        // Gemma 4 特殊处理
        prompt = buildGemma4Prompt(messages: processedMessages)
        
    case _ where modelFamily.contains("llama"):
        // Llama 格式
        prompt = buildLlamaPrompt(messages: processedMessages)
        
    case _ where modelFamily.contains("qwen"):
        // Qwen 格式
        prompt = buildQwenPrompt(messages: processedMessages)
        
    default:
        // 通用格式
        prompt = buildGenericPrompt(messages: processedMessages)
    }
    
    return prompt
}

// ✅ 更规范的 Gemma 4 格式构造
private func buildGemma4Prompt(messages: [(role: String, content: String)]) -> String {
    var prompt = ""
    for msg in messages {
        let sanitizedContent = msg.content
            .replacingOccurrences(of: "\r\n", with: "\n")  // 规范化换行
            .trimmingCharacters(in: .whitespaces)
        
        switch msg.role {
        case "user":
            prompt += "<|turn>user\n\(sanitizedContent)<turn|>\n"
        case "assistant", "model":
            prompt += "<|turn>model\n\(sanitizedContent)<turn|>\n"
        default:
            prompt += "<|turn>user\n\(sanitizedContent)<turn|>\n"
        }
    }
    prompt += "<|turn>model\n"
    return prompt
}
```

---

## 5. 完整修复方案

### 改进的 LlamaEngine.swift (关键部分)

```swift
import Foundation
import llama

final class LlamaEngine {
    
    // ... 现有代码 ...
    
    private var utf8Decoder: UTF8StreamDecoder?
    
    func generate(
        messages: [(role: String, content: String)],
        temperature: Float = 0.7,
        topK: Int32 = 40,
        topP: Float = 0.9,
        maxTokens: Int = 2048,
        repeatPenalty: Float = 1.1,
        onToken: @escaping (String) -> Void,
        isCancelled: @escaping () -> Bool
    ) throws {
        guard let model, let context else {
            throw LlamaEngineError.notLoaded
        }
        
        // ... 初始化代码 ...
        
        // ✅ 创建 UTF-8 解码器
        utf8Decoder = UTF8StreamDecoder()
        defer { utf8Decoder = nil }
        
        // ... Prefill 和其他初始化 ...
        
        // Decode 循环
        var generatedCount = 0
        
        while generatedCount < maxTokens && !isCancelled() {
            let newToken = llama_sampler_sample(sampler, context, -1)
            llama_sampler_accept(sampler, newToken)
            
            if llama_vocab_is_eog(vocab, newToken) {
                break
            }
            
            generatedCount += 1
            
            // ... Thinking channel 处理 ...
            
            // ✅ 改进的字节处理
            let piece = tokenToBytes(token: newToken)
            if !piece.isEmpty {
                let text = utf8Decoder!.decode(piece)  // 使用解码器
                if !text.isEmpty {
                    onToken(text)
                }
            }
            
            // ... 后续处理 ...
        }
        
        // ✅ 处理残留字节
        if let remaining = utf8Decoder?.flush(), !remaining.isEmpty {
            onToken(remaining)
        }
        
        print("[LlamaEngine] 生成完成: \(generatedCount) tokens")
    }
    
    // ✅ 改进的 tokenToBytes 方法
    private func tokenToBytes(token: llama_token) -> [UInt8] {
        guard let vocab = model.map({ llama_model_get_vocab($0) }) else { return [] }
        
        var buf = [CChar](repeating: 0, count: 256)
        let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, true)
        if n > 0 {
            // ✅ 使用 Data 包装器安全转换
            let data = Data(bytes: buf, count: Int(n))
            return [UInt8](data)
        }
        return []
    }
}

// ✅ 添加 UTF8StreamDecoder 类
class UTF8StreamDecoder {
    private var buffer = Data()
    
    /// 添加字节块并返回可解码的字符串
    func decode(_ bytes: [UInt8]) -> String {
        buffer.append(contentsOf: bytes)
        return extractValidString()
    }
    
    /// 获取缓冲中的所有数据
    func flush() -> String {
        if buffer.isEmpty {
            return ""
        }
        // 强制解码，使用替代字符替换无效 UTF-8
        let result = String(decoding: buffer, as: UTF8.self)
        buffer.removeAll()
        return result
    }
    
    // 私有方法
    private func extractValidString() -> String {
        var validEnd = 0
        var index = 0
        
        while index < buffer.count {
            let byte = buffer[index]
            let charLen: Int
            
            if (byte & 0x80) == 0 {
                charLen = 1
            } else if (byte & 0xE0) == 0xC0 {
                charLen = 2
            } else if (byte & 0xF0) == 0xE0 {
                charLen = 3
            } else if (byte & 0xF8) == 0xF0 {
                charLen = 4
            } else {
                // 无效的首字节，跳过
                index += 1
                continue
            }
            
            if index + charLen > buffer.count {
                break  // 不完整的字符
            }
            
            validEnd = index + charLen
            index += charLen
        }
        
        if validEnd == 0 {
            return ""
        }
        
        let validData = buffer.subdata(in: 0..<validEnd)
        let result = String(data: validData, encoding: .utf8) ?? ""
        buffer = buffer.subdata(in: validEnd..<buffer.count)
        
        return result
    }
}
```

---

## 6. 测试用例

### 需要测试的场景

```swift
// 测试 1: 中文字符
let testChinese = "你好世界"  // 每个字都是 3 字节 UTF-8

// 测试 2: Emoji
let testEmoji = "Hello 👋 World 🚀"

// 测试 3: 混合
let testMixed = "iOS 开发是 fun! 😄"

// 测试 4: 特殊字符
let testSpecial = "C++ & Python | Java"

// 测试 5: 在 UTF-8 边界的转换
// 模拟 token 在多字节 UTF-8 字符中间分割
let testBoundary = "Hello中世界"
// 如果分割成 "Hello中" 和 "世界"，确保不会产生乱码
```

---

## 7. 总结

| 问题 | 位置 | 严重程度 | 修复方案 |
|------|------|---------|---------|
| CChar 位转换 | 第 343-352 行 | 低-中 | 使用 Data 包装或 withUnsafeBytes |
| UTF-8 边界断裂 | 第 181-191 行 | 高 | 实现 UTF8StreamDecoder |
| 残留字节丢弃 | 第 202-207 行 | 中 | 使用强制解码或记录日志 |
| Chat Template 编码 | 第 214-286 行 | 低-中 | 验证模型特定格式 |

**建议优先级**: UTF-8 边界 > Chat Template > 残留字节 > CChar 转换


# iOS Client AI Infra - UTF-8 编码修复实现指南

## 概述

本指南说明如何应用 UTF-8 编码问题的修复。已提供的改进版 `LlamaEngine.swift` 包含了所有建议的修复，可直接替换原版本。

---

## 已应用的改进

### 1. UTF8StreamDecoder 类 (核心修复)

**文件**: `LlamaEngine.swift` (第 15-95 行)

**作用**: 正确处理 token 边界处的 UTF-8 多字节字符分割问题

**关键特性**:
- ✅ 识别 UTF-8 字符边界（1、2、3、4 字节字符）
- ✅ 缓冲不完整字符直到收到所有字节
- ✅ 避免中文、Emoji 等多字节字符被错误拆分
- ✅ `decode()` 方法：逐步处理字节流
- ✅ `flush()` 方法：流结束时处理残留字节

**示例**:
```swift
// 使用示例
let decoder = UTF8StreamDecoder()

// Token 1 返回中文"你"的首字节
let text1 = decoder.decode([0xE4])  // 返回 "" (不完整)

// Token 2 返回剩余字节
let text2 = decoder.decode([0xBD, 0xA0])  // 返回 "你" ✅

// 流结束
let remaining = decoder.flush()  // 处理任何残留字节
```

### 2. 在 generate() 方法中的集成 (第 262-269 行)

**变更点**:
```swift
// ❌ 旧代码：简单的 Data buffer
var utf8Buffer = Data()

// ✅ 新代码：使用 UTF8StreamDecoder
let utf8Decoder = UTF8StreamDecoder()
```

**Token 处理循环 (第 297-305 行)**:
```swift
// ❌ 旧代码：可能导致乱码
let piece = tokenToBytes(token: newToken)
if !piece.isEmpty {
    utf8Buffer.append(contentsOf: piece)
    if let text = String(data: utf8Buffer, encoding: .utf8) {
        // 解码失败时默认丢弃字节
    }
}

// ✅ 新代码：正确处理 UTF-8 边界
let piece = tokenToBytes(token: newToken)
if !piece.isEmpty {
    let text = utf8Decoder.decode(piece)
    if !text.isEmpty {
        onToken(text)
    }
}
```

**残留字节处理 (第 311-315 行)**:
```swift
// ❌ 旧代码：无法处理不完整序列
if !utf8Buffer.isEmpty {
    if let text = String(data: utf8Buffer, encoding: .utf8), !text.isEmpty {
        onToken(text)
    }
    // 失败时信息丢失
}

// ✅ 新代码：强制解码残留字节
let remainingText = utf8Decoder.flush()
if !remainingText.isEmpty {
    onToken(remainingText)
}
```

### 3. tokenToBytes() 方法改进 (第 360-371 行)

**改进内容**:
```swift
// ❌ 旧方法：依赖 bitPattern（有潜在风险）
return (0..<Int(n)).map { UInt8(bitPattern: buf[$0]) }

// ✅ 新方法：使用 Data 包装器（更安全）
let data = Data(bytes: buf, count: Int(n))
return [UInt8](data)
```

**优势**:
- 避免 CChar 有符号/无符号转换问题
- Data 的初始化器更可靠
- 符合 Swift 标准库推荐做法

---

## 验证修复

### 编译检查
```bash
cd /Users/guodongpeng/Desktop/SourceCode/github/ios-client-ai-infra
xcodebuild build -scheme AIInfraApp -configuration Debug 2>&1 | grep -i error
```

### 单元测试案例

建议添加单元测试验证 UTF8StreamDecoder：

```swift
// Tests/LlamaEngineTests.swift
import XCTest
@testable import AIInfraApp

class UTF8StreamDecoderTests: XCTestCase {
    
    func testSingleByteASCII() {
        let decoder = UTF8StreamDecoder()
        let result = decoder.decode([0x48, 0x65, 0x6C, 0x6C, 0x6F])  // "Hello"
        XCTAssertEqual(result, "Hello")
    }
    
    func testChineseCharacterSplitAcrossTokens() {
        let decoder = UTF8StreamDecoder()
        
        // "你" = E4 BD A0 (3 bytes)
        // 分成两个 token
        let part1 = decoder.decode([0xE4])
        XCTAssertEqual(part1, "")  // 不完整，返回空
        
        let part2 = decoder.decode([0xBD, 0xA0])
        XCTAssertEqual(part2, "你")  // 完整字符返回
    }
    
    func testEmojiCharacterSplitAcrossTokens() {
        let decoder = UTF8StreamDecoder()
        
        // "😀" = F0 9F 98 80 (4 bytes)
        let part1 = decoder.decode([0xF0, 0x9F])
        XCTAssertEqual(part1, "")
        
        let part2 = decoder.decode([0x98, 0x80])
        XCTAssertEqual(part2, "😀")
    }
    
    func testMixedContent() {
        let decoder = UTF8StreamDecoder()
        
        // "Hello 你好 😀"
        let text1 = decoder.decode("Hello ".utf8.map { $0 })
        XCTAssertEqual(text1, "Hello ")
        
        let text2 = decoder.decode([0xE4, 0xBD])  // 不完整的"你"
        XCTAssertEqual(text2, "")
        
        let text3 = decoder.decode([0xA0])  // 完成"你"
        XCTAssertEqual(text3, "你")
        
        let text4 = decoder.decode([0xE5, 0xA5, 0xBD])  // 完整的"好"
        XCTAssertEqual(text4, "好")
        
        let text5 = decoder.decode([0xF0, 0x9F, 0x98, 0x80])  // 完整的"😀"
        XCTAssertEqual(text5, " 😀")
        
        let remaining = decoder.flush()
        XCTAssertEqual(remaining, "")
    }
    
    func testFlushPartialCharacter() {
        let decoder = UTF8StreamDecoder()
        
        // 不完整的"你"字
        _ = decoder.decode([0xE4, 0xBD])
        
        let flushed = decoder.flush()
        // flush() 会用替代字符处理，不应该是空
        XCTAssertFalse(flushed.isEmpty)
    }
}
```

### 手动测试步骤

1. **准备测试模型**: 使用 Qwen2.5 0.5B (中文好)
2. **输入含中文/Emoji 的问题**: "用 5 个字描述你的功能 😊"
3. **观察输出**:
   - ✅ 修复前后对比：之前可能看到 `?` 或 `乱码`
   - ✅ 修复后应该看到正确的中文和 Emoji

### 性能验证

```swift
// 检查 UTF8StreamDecoder 的性能
let decoder = UTF8StreamDecoder()
let largeData = [UInt8](repeating: 0x41, count: 100_000)  // 100KB ASCII

let start = Date()
for i in 0..<1000 {
    _ = decoder.decode(Array(largeData[0..<100]))
}
let elapsed = Date().timeIntervalSince(start)
print("处理 100MB 数据耗时: \(elapsed)s")  // 应该 < 0.1s
```

---

## 与远程 API 的一致性

OpenAI 兼容 API (Ollama) 也在 `OpenAICompatibleProvider.swift` 中处理 UTF-8：

```swift
// 远程 API 的 SSE 解析 (第 251-254 行)
guard let content = chunk.choices.first?.delta.content,
      !content.isEmpty else { continue }
continuation.yield(StreamToken(text: content, isFinished: false, metrics: nil))
```

远程 API 的优势：
- 服务器端已完成完整的 token 到文本的转换
- 直接返回正确的 UTF-8 字符串
- 无需担心 token 边界问题

---

## 后续改进建议

### 优先级 1 (关键)
- ✅ 应用 UTF8StreamDecoder (已完成)
- ✅ 改进 tokenToBytes() 方法 (已完成)
- ⏳ 添加单元测试
- ⏳ 与产品验证中文/Emoji 输出

### 优先级 2 (重要)
- ⏳ 模型特定的 Chat Template 构建器（分离 Gemma/Llama/Qwen 逻辑）
- ⏳ 缓冲大小自适应（基于模型的平均 token 字节大小）

### 优先级 3 (优化)
- ⏳ 性能监测：UTF8StreamDecoder 吞吐量统计
- ⏳ 错误恢复：在无效 UTF-8 序列时的自动降级
- ⏳ 本地化：支持其他语言的测试用例

---

## 文件修改汇总

| 文件 | 修改行数 | 主要改进 |
|------|--------|---------|
| LlamaEngine.swift | 第 15-95 行 | 新增 UTF8StreamDecoder 类 |
| LlamaEngine.swift | 第 262-269 行 | 初始化 decoder 替代 Data buffer |
| LlamaEngine.swift | 第 297-305 行 | 使用 decoder.decode() 替代直接缓冲 |
| LlamaEngine.swift | 第 311-315 行 | 使用 decoder.flush() 替代简单的 nil 检查 |
| LlamaEngine.swift | 第 360-371 行 | 使用 Data 初始化器替代 bitPattern |

---

## 常见问题

### Q: 为什么中文显示为 `?` ?
**A**: 这通常表示 UTF-8 字符在 token 边界被分割。UTF8StreamDecoder 会缓冲不完整的字符直到收到所有字节。

### Q: 性能会下降吗？
**A**: 不会。UTF8StreamDecoder 的字节扫描是 O(n)，与原来的 Data 操作复杂度相同。实际上由于减少了失败的解码尝试，性能可能略好。

### Q: 支持所有 Unicode 字符吗？
**A**: 是的。UTF8StreamDecoder 完全支持 UTF-8 编码的所有 Unicode 字符（包括 BMP 和补充平面）。

### Q: 如何调试 UTF-8 问题？
**A**: 启用日志（见 UTF8StreamDecoder 第 79-81 行的 flush() 方法），它会打印无法解码的字节序列。

---

## 相关文档

- `ENCODING_ISSUES_ANALYSIS.md` - 详细的问题分析和三种解决方案对比
- `PROJECT_STRUCTURE_ANALYSIS.md` - 工程整体结构
- `QUICK_REFERENCE.md` - 快速查找指南


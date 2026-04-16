//
//  LlamaEngine.swift
//  AIInfraApp
//
//  llama.cpp C API 的 Swift 桥接层
//  通过 SPM binaryTarget 引入 llama.xcframework (b8783)
//  支持所有模型架构，包括 Gemma 4
//
//  改进版本：修复 UTF-8 编码问题，改善响应文本质量
//

import Foundation
import llama

// MARK: - UTF-8 流式解码器

/// 处理 token 边界处 UTF-8 多字节字符的正确解码
/// 避免中文、Emoji 等多字节字符被错误分割导致乱码
class UTF8StreamDecoder {
    private var buffer = Data()
    
    /// 添加字节块并尝试解码有效的 UTF-8 字符串
    /// 返回成功解码的字符串，残留字节保留在 buffer 中
    func decode(_ bytes: [UInt8]) -> String {
        buffer.append(contentsOf: bytes)
        
        // 从 buffer 的起始位置找到最后一个完整的 UTF-8 字符的位置
        var validEnd = 0
        var index = 0
        
        while index < buffer.count {
            let byte = buffer[index]
            let charLen: Int
            
            // 根据首字节确定此字符需要多少个字节
            if (byte & 0x80) == 0 {
                // 0xxxxxxx - 单字节 ASCII 字符
                charLen = 1
            } else if (byte & 0xE0) == 0xC0 {
                // 110xxxxx 10xxxxxx - 2 字节字符
                charLen = 2
            } else if (byte & 0xF0) == 0xE0 {
                // 1110xxxx 10xxxxxx 10xxxxxx - 3 字节字符（中文）
                charLen = 3
            } else if (byte & 0xF8) == 0xF0 {
                // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx - 4 字节字符（Emoji）
                charLen = 4
            } else {
                // 无效的 UTF-8 首字节，跳过此字节
                index += 1
                validEnd = index
                continue
            }
            
            // 检查是否有足够的字节形成完整的字符
            if index + charLen > buffer.count {
                // 字符不完整，停止处理
                break
            }
            
            validEnd = index + charLen
            index += charLen
        }
        
        // 解码完整的字符部分
        if validEnd > 0 {
            let validData = buffer.subdata(in: 0..<validEnd)
            let result = String(data: validData, encoding: .utf8) ?? ""
            
            // 保留残留的不完整字节
            buffer = buffer.subdata(in: validEnd..<buffer.count)
            
            return result
        }
        
        return ""
    }
    
    /// 获取缓冲中的残留字节（流结束时调用）
    /// 尝试强制解码，即使字节序列不完整
    func flush() -> String {
        if buffer.isEmpty {
            return ""
        }
        
        // 尝试解码残留字节，String(decoding:as:) 会用替代字符替换无效 UTF-8
        let result = String(decoding: buffer, as: UTF8.self)
        
        if result.isEmpty {
            return ""
        }
        
        // 记录警告信息便于调试
        if buffer.count > 0 {
            let hexStr = buffer.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("[UTF8StreamDecoder] 警告：残留字节已强制解码: \(hexStr)")
        }
        
        buffer.removeAll()
        return result
    }
}

// MARK: - Llama Engine

/// llama.cpp 的 Swift 封装，负责模型加载、推理、采样
final class LlamaEngine {

    private var model: OpaquePointer?    // llama_model * (opaque)
    private var context: OpaquePointer?  // llama_context * (opaque)
    private var sampler: UnsafeMutablePointer<llama_sampler>?

    private let modelPath: String
    private let contextLength: UInt32
    private let gpuEnabled: Bool

    /// 模型是否已加载
    var isLoaded: Bool { model != nil && context != nil }

    init(modelPath: String, contextLength: UInt32 = 2048, gpuEnabled: Bool = true) {
        self.modelPath = modelPath
        self.contextLength = contextLength
        self.gpuEnabled = gpuEnabled
    }

    deinit {
        unload()
    }

    // MARK: - 加载 / 卸载

    func load() throws {
        llama_backend_init()

        // 1. 加载模型
        var modelParams = llama_model_default_params()
        if !gpuEnabled {
            modelParams.n_gpu_layers = 0
        } else {
            modelParams.n_gpu_layers = 999 // 尽可能用 GPU
        }

        print("[LlamaEngine] 加载模型: \(modelPath)")
        model = llama_model_load_from_file(modelPath, modelParams)
        guard model != nil else {
            throw LlamaEngineError.loadFailed("无法加载模型文件，可能架构不支持或文件损坏")
        }

        // 2. 创建上下文
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = contextLength
        ctxParams.n_batch = 512
        ctxParams.n_threads = Int32(max(ProcessInfo.processInfo.activeProcessorCount - 2, 1))

        context = llama_init_from_model(model, ctxParams)
        guard context != nil else {
            llama_model_free(model)
            model = nil
            throw LlamaEngineError.loadFailed("无法创建推理上下文")
        }

        // 3. 打印调试信息
        print("[LlamaEngine] 模型加载成功, ctx=\(contextLength), threads=\(ctxParams.n_threads)")
    }

    func unload() {
        if let s = sampler { llama_sampler_free(s); sampler = nil }
        if let c = context { llama_free(c); context = nil }
        if let m = model { llama_model_free(m); model = nil }
        llama_backend_free()
    }

    // MARK: - 对话生成

    /// 应用 chat template 并执行流式推理
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

        let vocab = llama_model_get_vocab(model)

        // 0. 清空 KV cache
        let memory = llama_get_memory(context)
        llama_memory_clear(memory, true)

        // 1. 构建 prompt
        let prompt = applyChatTemplate(messages: messages)

        // 2. Tokenize
        let tokens = tokenize(text: prompt, addSpecial: true)
        guard !tokens.isEmpty else {
            throw LlamaEngineError.tokenizeFailed
        }
        print("[LlamaEngine] token 数: \(tokens.count), context 容量: \(contextLength)")

        if tokens.count >= Int(contextLength) {
            throw LlamaEngineError.decodeFailed("Prompt token 数(\(tokens.count))超过 context 容量(\(contextLength))，请缩短对话历史")
        }

        // 3. 创建采样链
        if let s = sampler { llama_sampler_free(s) }
        let chainParams = llama_sampler_chain_default_params()
        sampler = llama_sampler_chain_init(chainParams)
        guard let sampler else { throw LlamaEngineError.samplerFailed }

        // 采样器顺序：repetition penalty → top_k → top_p → temperature → dist
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(
            64,               // penalty_last_n: 回看 64 个 token（不要太大，小模型容易被惩罚到无话可说）
            repeatPenalty,    // penalty_repeat
            0.0,              // penalty_freq
            0.0               // penalty_present
        ))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(topK))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        // 4. Prefill
        var tokensCopy = tokens
        let batch = tokensCopy.withUnsafeMutableBufferPointer { ptr in
            llama_batch_get_one(ptr.baseAddress, Int32(tokens.count))
        }
        let prefillResult = llama_decode(context, batch)
        guard prefillResult == 0 else {
            throw LlamaEngineError.decodeFailed("Prefill 失败 (code: \(prefillResult))")
        }

        // 5. Decode：逐 token 生成
        var generatedCount = 0

        // ✅ 改进：使用 UTF8StreamDecoder 而不是简单的 Data buffer
        let utf8Decoder = UTF8StreamDecoder()

        // Gemma 4 thinking channel 相关 token（仅 Gemma 4 模型需要过滤）
        // id=100 <|channel>, id=101 <channel|>, id=98 <|think|>
        let isGemma4 = detectModelFamily() == "gemma4"
        let thinkingTokens: Set<llama_token> = [98, 100, 101]
        var inThinkingChannel = false

        while generatedCount < maxTokens && !isCancelled() {
            let newToken = llama_sampler_sample(sampler, context, -1)
            llama_sampler_accept(sampler, newToken)

            // 检查是否是 EOG（<turn|> 或 <eos>）
            if llama_vocab_is_eog(vocab, newToken) {
                break
            }

            generatedCount += 1

            // 处理 thinking channel：仅 Gemma 4 模型跳过 <|channel>...<channel|> 之间的内容
            if isGemma4 {
                if newToken == 100 { // <|channel>
                    inThinkingChannel = true
                    continue
                }
                if newToken == 101 { // <channel|>
                    inThinkingChannel = false
                    continue
                }
                if thinkingTokens.contains(newToken) {
                    continue
                }
                if inThinkingChannel {
                    // 在 thinking channel 中，不输出给用户
                    continue
                }
            }

            // ✅ 改进：使用 UTF8StreamDecoder 处理 token 字节
            let piece = tokenToBytes(token: newToken)
            if !piece.isEmpty {
                let text = utf8Decoder.decode(piece)
                if !text.isEmpty {
                    onToken(text)
                }
            }

            // 把新 token 喂回去
            var tokenBuf: [llama_token] = [newToken]
            let nextBatch = tokenBuf.withUnsafeMutableBufferPointer { ptr in
                llama_batch_get_one(ptr.baseAddress, 1)
            }
            let decodeResult = llama_decode(context, nextBatch)
            if decodeResult != 0 {
                print("[LlamaEngine] decode 出错: \(decodeResult)")
                break
            }
        }

        // ✅ 改进：正确处理残留字节
        let remainingText = utf8Decoder.flush()
        if !remainingText.isEmpty {
            onToken(remainingText)
        }

        print("[LlamaEngine] 生成完成: \(generatedCount) tokens")
    }

    // MARK: - 模型家族检测

    /// 根据模型文件名推断模型家族，用于选择正确的 fallback chat template
    private func detectModelFamily() -> String {
        let name = modelPath.lowercased()
        if name.contains("qwen") { return "qwen" }
        if name.contains("llama") || name.contains("smollm") { return "llama3" }
        if name.contains("phi") { return "phi" }
        if name.contains("gemma-2") || name.contains("gemma2") { return "gemma2" }
        if name.contains("gemma") { return "gemma4" }  // gemma-4 / gemma4
        return "chatml"  // 通用 fallback（ChatML 格式，兼容性最好）
    }

    // MARK: - Chat Template

    private func applyChatTemplate(messages: [(role: String, content: String)]) -> String {
        guard let model else { return "" }

        // 预处理：将 system 消息合并到第一条 user 消息
        let processedMessages = preprocessMessages(messages)

        // 将 role/content 转为持久 C 字符串（堆分配，指针在整个函数作用域内有效）
        let cRoles = processedMessages.map { strdup($0.role)! }
        let cContents = processedMessages.map { strdup($0.content)! }
        defer {
            cRoles.forEach { free($0) }
            cContents.forEach { free($0) }
        }

        // 构建 llama_chat_message 数组
        var cMessages: [llama_chat_message] = []
        for i in 0..<processedMessages.count {
            cMessages.append(llama_chat_message(
                role: UnsafePointer(cRoles[i]),
                content: UnsafePointer(cContents[i])
            ))
        }

        var buf = [CChar](repeating: 0, count: 32768)

        // 辅助函数：用给定 template 尝试格式化
        func tryTemplate(_ tmpl: UnsafePointer<CChar>?, label: String) -> String? {
            let result = cMessages.withUnsafeMutableBufferPointer { msgPtr in
                llama_chat_apply_template(
                    tmpl,
                    msgPtr.baseAddress,
                    Int(msgPtr.count),
                    true,
                    &buf,
                    Int32(buf.count)
                )
            }
            if result > 0 {
                let text = String(cString: buf)
                print("[LlamaEngine] chat template 成功 (\(label)), prompt 长度: \(text.count)")
                // 验证：如果生成的 prompt 包含模型实际使用的标记，才认为真正成功
                return text
            }
            print("[LlamaEngine] chat template 失败 (\(label)), result=\(result)")
            return nil
        }

        // 1. 模型内置 template（从 GGUF metadata 读取）
        //    注意：Gemma 4 的模板是 jinja 格式，llama_chat_apply_template 不支持 jinja，会返回 -1
        let modelTmpl = llama_model_chat_template(model, nil)
        if let r = tryTemplate(modelTmpl, label: "model-builtin") {
            return r
        }

        // 2. 模型内置 jinja 模板不可用时，根据模型家族选择正确的 fallback 模板
        let family = detectModelFamily()
        print("[LlamaEngine] 使用 fallback 模板，模型家族: \(family)")

        var prompt = ""

        switch family {
        case "qwen":
            // Qwen2.5 系列：ChatML 变体
            for msg in processedMessages {
                let role = (msg.role == "assistant") ? "assistant" : msg.role
                prompt += "<|im_start|>\(role)\n\(msg.content)<|im_end|>\n"
            }
            prompt += "<|im_start|>assistant\n"

        case "llama3":
            // Llama 3.x / SmolLM2 系列
            prompt += "<|begin_of_text|>"
            for msg in processedMessages {
                let role = (msg.role == "assistant") ? "assistant" : msg.role
                prompt += "<|start_header_id|>\(role)<|end_header_id|>\n\n\(msg.content)<|eot_id|>"
            }
            prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n"

        case "phi":
            // Phi-3.5 系列
            for msg in processedMessages {
                switch msg.role {
                case "user":
                    prompt += "<|user|>\n\(msg.content)<|end|>\n"
                case "assistant":
                    prompt += "<|assistant|>\n\(msg.content)<|end|>\n"
                default:
                    prompt += "<|user|>\n\(msg.content)<|end|>\n"
                }
            }
            prompt += "<|assistant|>\n"

        case "gemma2":
            // Gemma 2 系列：<start_of_turn> 格式
            for msg in processedMessages {
                let role = (msg.role == "assistant") ? "model" : msg.role
                prompt += "<start_of_turn>\(role)\n\(msg.content)<end_of_turn>\n"
            }
            prompt += "<start_of_turn>model\n"

        case "gemma4":
            // Gemma 4 系列：<|turn> 格式
            for msg in processedMessages {
                let role = (msg.role == "assistant") ? "model" : msg.role
                prompt += "<|turn>\(role)\n\(msg.content)<turn|>\n"
            }
            prompt += "<|turn>model\n"

        default:
            // 通用 ChatML fallback（Qwen/Mistral/Yi 等兼容此格式）
            for msg in processedMessages {
                let role = (msg.role == "assistant") ? "assistant" : msg.role
                prompt += "<|im_start|>\(role)\n\(msg.content)<|im_end|>\n"
            }
            prompt += "<|im_start|>assistant\n"
        }

        return prompt
    }

    /// 预处理消息：将 system 消息合并到第一条 user 消息中（Gemma 不支持 system role）
    private func preprocessMessages(_ messages: [(role: String, content: String)]) -> [(role: String, content: String)] {
        var systemContent = ""
        var result: [(role: String, content: String)] = []
        var firstUserFound = false

        for msg in messages {
            if msg.role == "system" {
                systemContent += msg.content + "\n"
            } else if msg.role == "user" && !firstUserFound {
                firstUserFound = true
                if systemContent.isEmpty {
                    result.append(msg)
                } else {
                    // 将 system 指令前置到第一条 user 消息
                    result.append((role: "user", content: systemContent + msg.content))
                }
            } else {
                result.append(msg)
            }
        }

        // 如果只有 system 消息，没有 user 消息
        if !firstUserFound && !systemContent.isEmpty {
            result.append((role: "user", content: systemContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return result
    }

    // MARK: - Tokenize / Detokenize

    private func tokenize(text: String, addSpecial: Bool) -> [llama_token] {
        guard let vocab = model.map({ llama_model_get_vocab($0) }) else { return [] }

        // 使用 withCString 确保正确传递 const char *
        return text.withCString { cStr in
            let textLen = Int32(strlen(cStr))
            let maxTokens = Int(textLen) + (addSpecial ? 16 : 0) + 64
            var tokens = [llama_token](repeating: 0, count: maxTokens)

            let n = llama_tokenize(vocab, cStr, textLen, &tokens, Int32(maxTokens), addSpecial, true)

            if n < 0 {
                // buffer 不够，扩大重试
                tokens = [llama_token](repeating: 0, count: Int(-n))
                let n2 = llama_tokenize(vocab, cStr, textLen, &tokens, Int32(-n), addSpecial, true)
                return n2 > 0 ? Array(tokens.prefix(Int(n2))) : []
            }

            return n > 0 ? Array(tokens.prefix(Int(n))) : []
        }
    }

    /// 将 token 转为原始 UTF-8 字节（不尝试解码为 String，由调用方累积后解码）
    /// ✅ 改进：使用 Data 包装器安全处理 CChar 到 UInt8 的转换
    private func tokenToBytes(token: llama_token) -> [UInt8] {
        guard let vocab = model.map({ llama_model_get_vocab($0) }) else { return [] }

        var buf = [CChar](repeating: 0, count: 256)
        let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, true)
        if n > 0 {
            // ✅ 改进：使用 Data 初始化器，确保正确的位转换
            let data = Data(bytes: buf, count: Int(n))
            return [UInt8](data)
        }
        return []
    }
}

// MARK: - 错误

enum LlamaEngineError: LocalizedError {
    case loadFailed(String)
    case notLoaded
    case tokenizeFailed
    case samplerFailed
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let msg): return "模型加载失败: \(msg)"
        case .notLoaded: return "模型未加载"
        case .tokenizeFailed: return "文本分词失败"
        case .samplerFailed: return "采样器初始化失败"
        case .decodeFailed(let msg): return "推理失败: \(msg)"
        }
    }
}

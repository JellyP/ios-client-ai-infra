import Foundation

// MARK: - Mock 端侧模型提供者

/// 端侧模型的 Mock 实现，用于 Demo 演示。
/// 真实实现需要集成 llama.cpp 或 CoreML。
final class MockOnDeviceProvider: AIModelProvider, @unchecked Sendable {

    let id: String
    let displayName: String
    let description: String
    let descriptionEN: String
    let providerType: AIModelProviderType = .onDevice
    let architectureType: ModelArchitectureType
    let modelInfo: ModelInfo
    let supportsImageClassification: Bool
    private(set) var state: AIModelState = .unloaded
    private var isCancelled = false

    init(
        id: String,
        displayName: String,
        description: String,
        family: String,
        parameterCount: String,
        quantization: String = "Q4_K_M",
        fileSize: Int64,
        architectureType: ModelArchitectureType = .dense
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.descriptionEN = description
        self.architectureType = architectureType
        self.supportsImageClassification = false
        self.modelInfo = ModelInfo(
            family: family,
            parameterCount: parameterCount,
            quantization: quantization,
            fileSize: fileSize,
            contextLength: 2048,
            supportedLanguages: ["en", "zh"],
            summary: description
        )
    }

    func load() async throws {
        // 模拟模型下载
        state = .downloading(progress: 0)
        for i in 1...10 {
            try await Task.sleep(for: .milliseconds(100))
            state = .downloading(progress: Double(i) / 10.0)
        }

        // 模拟模型加载到内存
        state = .loading
        try await Task.sleep(for: .milliseconds(800))

        state = .ready
    }

    func unload() {
        state = .unloaded
    }

    func chat(messages: [ChatMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamToken, Error> {
        AsyncThrowingStream { continuation in
            Task {
                self.isCancelled = false
                self.state = .generating

                let startTime = CFAbsoluteTimeGetCurrent()
                let memoryBefore = MemoryUtils.currentMemoryUsage

                // 模拟 Prefill 阶段（端侧模型 Prefill 通常更快）
                try? await Task.sleep(for: .milliseconds(Int.random(in: 100...300)))

                let prefillTime = CFAbsoluteTimeGetCurrent() - startTime

                // 模拟生成回复
                let response = self.generateMockResponse(for: messages.last?.content ?? "")
                let tokens = self.tokenizeForDisplay(response)

                var generatedCount = 0
                let decodeStartTime = CFAbsoluteTimeGetCurrent()

                for (index, token) in tokens.enumerated() {
                    if self.isCancelled { break }

                    // 模拟端侧推理速度（端侧模型通常 5-30 tokens/s，比远程慢）
                    let delay = self.simulateInferenceDelay()
                    try? await Task.sleep(for: .milliseconds(delay))

                    generatedCount += 1
                    let isLast = index == tokens.count - 1

                    let metrics: GenerationMetrics? = isLast ? GenerationMetrics(
                        modelName: self.displayName,
                        prefillTime: prefillTime,
                        prefillTokensPerSecond: Double(messages.last?.content.count ?? 0) / max(prefillTime, 0.001),
                        decodeTime: CFAbsoluteTimeGetCurrent() - decodeStartTime,
                        decodeTokensPerSecond: Double(generatedCount) / max(CFAbsoluteTimeGetCurrent() - decodeStartTime, 0.001),
                        timeToFirstToken: prefillTime,
                        totalGeneratedTokens: generatedCount,
                        totalTime: CFAbsoluteTimeGetCurrent() - startTime,
                        peakMemoryUsage: max(MemoryUtils.currentMemoryUsage, memoryBefore),
                        inputTokenCount: messages.last?.content.count ?? 0
                    ) : nil

                    continuation.yield(StreamToken(text: token, isFinished: isLast, metrics: metrics))
                }

                self.state = .ready
                continuation.finish()
            }
        }
    }

    func cancelGeneration() {
        isCancelled = true
        state = .ready
    }

    // MARK: - Private

    /// 模拟不同模型大小的推理延迟
    private func simulateInferenceDelay() -> Int {
        // 模型越大，推理越慢
        switch modelInfo.parameterCount {
        case "1B":
            return Int.random(in: 30...60)     // ~20 tokens/s
        case "1.5B":
            return Int.random(in: 40...80)     // ~15 tokens/s
        case "2B":
            return Int.random(in: 50...100)    // ~12 tokens/s
        case "3.8B":
            return Int.random(in: 70...140)    // ~8 tokens/s
        default:
            return Int.random(in: 50...100)
        }
    }

    private func generateMockResponse(for input: String) -> String {
        // 端侧模型的回复通常更简短、质量略低
        if input.contains("1+1") {
            return "2"
        } else if input.contains("翻译") || input.contains("Hello") {
            return "你好，你今天好吗？"
        } else if input.contains("iOS") {
            return "iOS开发是为Apple设备构建应用的过程，使用Swift语言和Apple框架。"
        } else if input.contains("排序") || input.contains("冒泡") {
            return """
            ```swift
            func bubbleSort(_ arr: inout [Int]) {
                for i in 0..<arr.count {
                    for j in 0..<arr.count - i - 1 {
                        if arr[j] > arr[j+1] {
                            arr.swapAt(j, j+1)
                        }
                    }
                }
            }
            ```
            """
        } else if input.contains("ARC") {
            return "ARC是自动引用计数，Swift用它管理内存。当对象没有被引用时自动释放。注意避免循环引用。"
        } else {
            return "[\(displayName) 端侧推理] 当前为模拟回复。集成 llama.cpp 后将提供真实的端侧模型推理结果。"
        }
    }

    private func tokenizeForDisplay(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if current.count >= 2 || char == "\n" || char == " " {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}

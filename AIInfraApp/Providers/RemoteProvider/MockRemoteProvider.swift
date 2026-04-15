import Foundation

// MARK: - Mock 远程模型提供者

/// 远程模型的 Mock 实现，用于 Demo 演示。
/// 真实实现需要替换为实际的 API 调用。
final class MockRemoteProvider: AIModelProvider, @unchecked Sendable {

    let id: String
    let displayName: String
    let description: String
    let providerType: AIModelProviderType = .remote
    let architectureType: ModelArchitectureType
    let modelInfo: ModelInfo
    private(set) var state: AIModelState = .unloaded
    private var isCancelled = false

    init(
        id: String,
        displayName: String,
        description: String,
        family: String,
        parameterCount: String,
        architectureType: ModelArchitectureType = .dense
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.architectureType = architectureType
        self.modelInfo = ModelInfo(
            family: family,
            parameterCount: parameterCount,
            quantization: "N/A",
            fileSize: 0,
            contextLength: 128_000,
            supportedLanguages: ["en", "zh", "ja", "ko", "fr", "de"],
            summary: description
        )
    }

    func load() async throws {
        state = .loading
        // 模拟 API 连通性检查
        try await Task.sleep(for: .milliseconds(500))
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

                // 模拟 Prefill 延迟
                try? await Task.sleep(for: .milliseconds(200))

                let prefillTime = CFAbsoluteTimeGetCurrent() - startTime

                // 模拟生成回复
                let response = self.generateMockResponse(for: messages.last?.content ?? "")
                let tokens = self.tokenizeForDisplay(response)

                var generatedCount = 0
                let decodeStartTime = CFAbsoluteTimeGetCurrent()

                for (index, token) in tokens.enumerated() {
                    if self.isCancelled { break }

                    // 模拟 token 生成延迟（远程模型通常 30-100 tokens/s）
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 15...40)))

                    generatedCount += 1
                    let isLast = index == tokens.count - 1

                    let metrics: GenerationMetrics? = isLast ? GenerationMetrics(
                        modelName: self.displayName,
                        prefillTime: prefillTime,
                        prefillTokensPerSecond: Double(messages.last?.content.count ?? 0) / prefillTime,
                        decodeTime: CFAbsoluteTimeGetCurrent() - decodeStartTime,
                        decodeTokensPerSecond: Double(generatedCount) / (CFAbsoluteTimeGetCurrent() - decodeStartTime),
                        timeToFirstToken: prefillTime,
                        totalGeneratedTokens: generatedCount,
                        totalTime: CFAbsoluteTimeGetCurrent() - startTime,
                        peakMemoryUsage: MemoryUtils.currentMemoryUsage,
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

    private func generateMockResponse(for input: String) -> String {
        // 根据输入生成简单的 Mock 回复
        if input.contains("1+1") {
            return "1+1等于2。"
        } else if input.contains("翻译") || input.contains("Hello") {
            return "你好，今天过得怎么样？"
        } else if input.contains("iOS") {
            return "iOS开发是使用Swift或Objective-C语言，基于Apple的UIKit或SwiftUI框架，为iPhone和iPad等设备构建应用程序的过程。它涉及界面设计、数据管理、网络通信等多个方面。"
        } else if input.contains("排序") || input.contains("冒泡") {
            return """
            ```swift
            func bubbleSort(_ array: inout [Int]) {
                let n = array.count
                for i in 0..<n {
                    for j in 0..<(n - i - 1) {
                        if array[j] > array[j + 1] {
                            array.swapAt(j, j + 1)
                        }
                    }
                }
            }
            ```
            """
        } else if input.contains("ARC") {
            return "ARC（自动引用计数）是Swift和Objective-C的内存管理机制。它通过跟踪每个对象被引用的次数，当引用计数为0时自动释放对象内存，开发者无需手动管理。需要注意循环引用问题，可用weak或unowned解决。"
        } else {
            return "这是 \(displayName) 的模拟回复。在实际实现中，这里会调用对应的 API 获取真实的模型回复。当前输入：\"\(input.prefix(50))...\""
        }
    }

    private func tokenizeForDisplay(_ text: String) -> [String] {
        // 简单地按字符分割，模拟 token 级别的流式输出
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

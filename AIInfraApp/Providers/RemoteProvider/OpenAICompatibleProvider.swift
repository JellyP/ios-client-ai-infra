import Foundation

// MARK: - API 配置

/// 远程模型 API 配置
struct RemoteAPIConfig {
    let baseURL: String
    let apiKey: String
    let modelId: String

    /// OpenAI 配置
    static func openAI(apiKey: String, model: String = "gpt-4o") -> RemoteAPIConfig {
        RemoteAPIConfig(baseURL: "https://api.openai.com/v1", apiKey: apiKey, modelId: model)
    }

    /// DeepSeek 配置（兼容 OpenAI 格式）
    static func deepSeek(apiKey: String, model: String = "deepseek-chat") -> RemoteAPIConfig {
        RemoteAPIConfig(baseURL: "https://api.deepseek.com/v1", apiKey: apiKey, modelId: model)
    }

    /// 自定义兼容 OpenAI 格式的 API（如 Ollama、vLLM、本地部署等）
    static func custom(baseURL: String, apiKey: String = "", model: String) -> RemoteAPIConfig {
        RemoteAPIConfig(baseURL: baseURL, apiKey: apiKey, modelId: model)
    }
}

// MARK: - API 请求/响应模型

/// Chat Completion 请求体（OpenAI 兼容格式）
private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [APIMessage]
    let stream: Bool
    let temperature: Float?
    let top_p: Float?
    let max_tokens: Int?

    struct APIMessage: Encodable {
        let role: String
        let content: String
    }
}

/// 非流式响应
private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String?
    }

    struct Usage: Decodable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
}

/// 流式响应（SSE chunk）
private struct ChatCompletionChunk: Decodable {
    let choices: [ChunkChoice]

    struct ChunkChoice: Decodable {
        let delta: Delta
        let finish_reason: String?
    }

    struct Delta: Decodable {
        let content: String?
    }
}

// MARK: - OpenAI 兼容 Provider

/// 真实的远程模型提供者，支持所有 OpenAI 兼容 API
/// （包括 OpenAI、DeepSeek、Ollama、vLLM 等）
final class OpenAICompatibleProvider: AIModelProvider, @unchecked Sendable {

    let id: String
    let displayName: String
    let description: String
    let providerType: AIModelProviderType = .remote
    let architectureType: ModelArchitectureType
    let modelInfo: ModelInfo
    private(set) var state: AIModelState = .unloaded

    private let config: RemoteAPIConfig
    private let session: URLSession
    private var currentTask: URLSessionDataTask?
    private var isCancelled = false

    init(
        id: String,
        displayName: String,
        description: String,
        config: RemoteAPIConfig,
        architectureType: ModelArchitectureType = .dense,
        modelInfo: ModelInfo
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.config = config
        self.architectureType = architectureType
        self.modelInfo = modelInfo

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Load / Unload

    func load() async throws {
        state = .loading

        // 验证 API 连通性：发一个简单请求
        var request = URLRequest(url: URL(string: "\(config.baseURL)/models")!)
        request.httpMethod = "GET"
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 || httpResponse.statusCode == 401 {
                // 401 也算连通（只是 key 可能有问题，但 API 是通的）
                state = .ready
            } else {
                // 即使无法验证，也允许使用（有些自部署服务没有 /models 端点）
                state = .ready
            }
        } catch {
            // 网络不通时仍标记为 ready，让用户在聊天时看到实际错误
            state = .ready
        }
    }

    func unload() {
        cancelGeneration()
        state = .unloaded
    }

    // MARK: - Chat (SSE 流式)

    func chat(messages: [ChatMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamToken, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                self.isCancelled = false
                self.state = .generating

                let startTime = CFAbsoluteTimeGetCurrent()
                let memoryBefore = MemoryUtils.currentMemoryUsage

                do {
                    // 构建请求
                    let apiMessages = messages.map {
                        ChatCompletionRequest.APIMessage(role: $0.role.rawValue, content: $0.content)
                    }

                    let requestBody = ChatCompletionRequest(
                        model: self.config.modelId,
                        messages: apiMessages,
                        stream: true,
                        temperature: config.temperature,
                        top_p: config.topP,
                        max_tokens: config.maxTokens
                    )

                    var request = URLRequest(url: URL(string: "\(self.config.baseURL)/chat/completions")!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if !self.config.apiKey.isEmpty {
                        request.setValue("Bearer \(self.config.apiKey)", forHTTPHeaderField: "Authorization")
                    }
                    request.httpBody = try JSONEncoder().encode(requestBody)

                    // 发起流式请求
                    let (bytes, response) = try await self.session.bytes(for: request)

                    // 检查 HTTP 状态码
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        let errorMsg: String
                        switch httpResponse.statusCode {
                        case 401: errorMsg = "API Key 无效，请检查配置"
                        case 429: errorMsg = "请求频率过高，请稍后重试"
                        case 500...599: errorMsg = "服务器错误 (\(httpResponse.statusCode))"
                        default: errorMsg = "HTTP 错误 \(httpResponse.statusCode)"
                        }
                        throw RemoteProviderError.apiError(errorMsg)
                    }

                    var generatedCount = 0
                    var prefillTime: TimeInterval = 0
                    var isFirstToken = true
                    let inputTokenCount = messages.last?.content.count ?? 0

                    // 解析 SSE 流
                    for try await line in bytes.lines {
                        if self.isCancelled { break }

                        // SSE 格式: "data: {...}" 或 "data: [DONE]"
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))

                        if jsonString == "[DONE]" {
                            // 流结束
                            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                            let decodeTime = totalTime - prefillTime

                            let metrics = GenerationMetrics(
                                modelName: self.displayName,
                                prefillTime: prefillTime,
                                prefillTokensPerSecond: Double(inputTokenCount) / max(prefillTime, 0.001),
                                decodeTime: decodeTime,
                                decodeTokensPerSecond: Double(generatedCount) / max(decodeTime, 0.001),
                                timeToFirstToken: prefillTime,
                                totalGeneratedTokens: generatedCount,
                                totalTime: totalTime,
                                peakMemoryUsage: max(MemoryUtils.currentMemoryUsage, memoryBefore),
                                inputTokenCount: inputTokenCount
                            )
                            continuation.yield(StreamToken(text: "", isFinished: true, metrics: metrics))
                            break
                        }

                        // 解析 JSON chunk
                        guard let data = jsonString.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data),
                              let content = chunk.choices.first?.delta.content,
                              !content.isEmpty else {
                            continue
                        }

                        if isFirstToken {
                            prefillTime = CFAbsoluteTimeGetCurrent() - startTime
                            isFirstToken = false
                        }

                        generatedCount += 1
                        let isFinished = chunk.choices.first?.finish_reason != nil

                        if isFinished {
                            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                            let decodeTime = totalTime - prefillTime
                            let metrics = GenerationMetrics(
                                modelName: self.displayName,
                                prefillTime: prefillTime,
                                prefillTokensPerSecond: Double(inputTokenCount) / max(prefillTime, 0.001),
                                decodeTime: decodeTime,
                                decodeTokensPerSecond: Double(generatedCount) / max(decodeTime, 0.001),
                                timeToFirstToken: prefillTime,
                                totalGeneratedTokens: generatedCount,
                                totalTime: totalTime,
                                peakMemoryUsage: max(MemoryUtils.currentMemoryUsage, memoryBefore),
                                inputTokenCount: inputTokenCount
                            )
                            continuation.yield(StreamToken(text: content, isFinished: true, metrics: metrics))
                        } else {
                            continuation.yield(StreamToken(text: content, isFinished: false, metrics: nil))
                        }
                    }

                } catch {
                    continuation.finish(throwing: error)
                }

                self.state = .ready
                continuation.finish()
            }
        }
    }

    func cancelGeneration() {
        isCancelled = true
        currentTask?.cancel()
        state = .ready
    }
}

// MARK: - 错误类型

enum RemoteProviderError: LocalizedError {
    case apiError(String)
    case networkError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return "API 错误: \(msg)"
        case .networkError(let msg): return "网络错误: \(msg)"
        case .invalidResponse: return "无效的 API 响应"
        }
    }
}

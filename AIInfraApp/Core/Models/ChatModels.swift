import Foundation

// MARK: - 对话消息

/// 对话消息模型
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// 消息角色
enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

// MARK: - 流式 Token

/// 流式输出的单个 Token
struct StreamToken {
    /// Token 文本内容
    let text: String

    /// 是否为最后一个 token
    let isFinished: Bool

    /// 附带的性能指标（仅最后一个 token 携带）
    let metrics: GenerationMetrics?
}

// MARK: - 生成配置

/// 模型生成配置参数
struct GenerationConfig {
    /// 最大生成 token 数
    var maxTokens: Int = 512

    /// 温度（0-2，越高越随机）
    var temperature: Float = 0.7

    /// Top-P 采样
    var topP: Float = 0.9

    /// Top-K 采样
    var topK: Int = 40

    /// 重复惩罚
    var repeatPenalty: Float = 1.1

    /// 默认配置
    static let `default` = GenerationConfig()

    /// 精确模式（低温度，适合代码/数学）
    static let precise = GenerationConfig(
        maxTokens: 1024,
        temperature: 0.1,
        topP: 0.95,
        topK: 20,
        repeatPenalty: 1.0
    )

    /// 创意模式（高温度，适合写作）
    static let creative = GenerationConfig(
        maxTokens: 1024,
        temperature: 1.0,
        topP: 0.95,
        topK: 50,
        repeatPenalty: 1.2
    )
}

// MARK: - 生成性能指标

/// 模型推理性能指标
struct GenerationMetrics: Codable {
    /// 模型名称
    let modelName: String

    /// Prefill 阶段耗时（秒）
    let prefillTime: TimeInterval

    /// Prefill 速度（tokens/s）
    let prefillTokensPerSecond: Double

    /// Decode 阶段耗时（秒）
    let decodeTime: TimeInterval

    /// Decode 速度（tokens/s，即生成速度）
    let decodeTokensPerSecond: Double

    /// 首 token 延迟（秒）
    let timeToFirstToken: TimeInterval

    /// 总生成 token 数
    let totalGeneratedTokens: Int

    /// 总耗时
    let totalTime: TimeInterval

    /// 峰值内存使用（bytes）
    let peakMemoryUsage: UInt64

    /// 输入 token 数
    let inputTokenCount: Int
}

// MARK: - 模型信息

/// 模型基本信息
struct ModelInfo: Codable {
    /// 模型家族（如 Llama、Gemma、Qwen）
    let family: String

    /// 参数量描述（如 "1.5B", "3B"）
    let parameterCount: String

    /// 量化级别（如 "Q4_K_M", "FP16"）
    let quantization: String

    /// 模型文件大小（bytes）
    let fileSize: Int64

    /// 上下文窗口大小
    let contextLength: Int

    /// 支持的语言
    let supportedLanguages: [String]

    /// 模型简介
    let summary: String
}

// MARK: - 对话会话

/// 对话会话
struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var modelId: String
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "新对话", modelId: String) {
        self.id = id
        self.title = title
        self.messages = []
        self.modelId = modelId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

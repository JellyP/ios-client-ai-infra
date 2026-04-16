import Foundation

// MARK: - AI 模型提供者协议

/// 所有模型提供者（远程 API / 端侧模型）的统一协议。
///
/// 设计原则：
/// - 协议驱动，方便扩展新模型
/// - 统一接口，UI 层不关心模型是远程还是本地
/// - 支持流式输出，实现打字机效果
protocol AIModelProvider: AnyObject, Identifiable, Sendable {

    /// 模型的唯一标识
    var id: String { get }

    /// 模型显示名称
    var displayName: String { get }

    /// 模型描述信息
    var description: String { get }

    /// 模型类型（远程 / 端侧）
    var providerType: AIModelProviderType { get }

    /// 模型架构类型（Dense / MoE）
    var architectureType: ModelArchitectureType { get }

    /// 模型当前状态
    var state: AIModelState { get }

    /// 模型信息（参数量、大小等）
    var modelInfo: ModelInfo { get }

    /// 加载模型（端侧模型需要加载到内存，远程模型验证 API 连通性）
    func load() async throws

    /// 卸载模型（释放资源）
    func unload()

    /// 发送消息并获取流式响应
    /// - Parameters:
    ///   - messages: 对话历史
    ///   - config: 生成配置
    /// - Returns: 流式输出的 token 序列
    func chat(messages: [ChatMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamToken, Error>

    /// 取消当前生成
    func cancelGeneration()
}

// MARK: - 模型提供者类型

/// 模型部署位置分类
enum AIModelProviderType: String, Codable, CaseIterable {
    /// 远程 API 模型（GPT、Claude 等）
    case remote = "远程模型"

    /// 端侧本地模型
    case onDevice = "端侧模型"
}

// MARK: - 模型架构类型

/// 模型架构分类
enum ModelArchitectureType: String, Codable, CaseIterable {
    /// Dense（稠密）模型 —— 所有参数都参与计算
    case dense = "Dense"

    /// MoE（混合专家）模型 —— 只激活部分参数
    case moe = "MoE"
}

// MARK: - 模型状态

/// 模型的生命周期状态
enum AIModelState: Equatable {
    /// 未加载
    case unloaded

    /// 正在下载模型文件（端侧模型）
    case downloading(progress: Double)

    /// 正在加载到内存
    case loading

    /// 已就绪，可以进行推理
    case ready

    /// 正在推理中
    case generating

    /// 发生错误
    case error(String)
}

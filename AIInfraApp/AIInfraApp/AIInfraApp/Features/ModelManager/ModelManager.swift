import Foundation

// MARK: - 模型管理器

/// 统一管理所有模型提供者的中心类
///
/// ## 集成指南
///
/// ### 远程模型 (OpenAI / DeepSeek)
/// 在 `registerRemoteProviders()` 中，将 API Key 填入即可启用真实 API 调用。
/// 当 API Key 为空时，自动 fallback 到 Mock 模式。
///
/// ### 端侧模型
/// 端侧模型先通过 App 内的"模型商店"下载 GGUF 文件到手机，
/// 然后由 `MockOnDeviceProvider` 提供推理（后续替换为 llama.cpp 真实推理）。
@MainActor
final class ModelManager: ObservableObject {

    /// 所有已注册的模型提供者
    @Published var providers: [any AIModelProvider] = []

    /// 当前选中的模型 ID
    @Published var selectedModelId: String?

    /// 当前选中的模型提供者
    var selectedProvider: (any AIModelProvider)? {
        providers.first { $0.id == selectedModelId }
    }

    init() {
        registerRemoteProviders()
        registerOnDeviceProviders()

        // 默认选中第一个端侧模型
        if let firstOnDevice = onDeviceProviders.first {
            selectedModelId = firstOnDevice.id
        } else if let firstRemote = remoteProviders.first {
            selectedModelId = firstRemote.id
        }
    }

    // MARK: - 远程模型注册

    /// 注册远程模型。API Key 不为空时使用真实 API，否则使用 Mock。
    private func registerRemoteProviders() {

        // ── OpenAI GPT-4o ──
        let openAIKey = APIKeyStore.openAIKey
        if !openAIKey.isEmpty {
            // ✅ 真实 API
            providers.append(
                OpenAICompatibleProvider(
                    id: "openai-gpt4o",
                    displayName: "GPT-4o",
                    description: "OpenAI 最强多模态模型，综合能力最佳（真实 API）",
                    config: .openAI(apiKey: openAIKey, model: "gpt-4o"),
                    architectureType: .dense,
                    modelInfo: ModelInfo(
                        family: "GPT", parameterCount: "~1.8T (估计)",
                        quantization: "N/A", fileSize: 0, contextLength: 128_000,
                        supportedLanguages: ["en", "zh", "ja", "ko", "fr", "de"],
                        summary: "OpenAI 旗舰模型，综合能力最强"
                    )
                )
            )
        } else {
            // Mock 模式
            providers.append(
                MockRemoteProvider(
                    id: "openai-gpt4o",
                    displayName: "GPT-4o (Mock)",
                    description: "模拟模式 — 设置 API Key 后启用真实 API",
                    family: "GPT",
                    parameterCount: "~1.8T (估计)"
                )
            )
        }

        // ── DeepSeek-V3 (MoE) ──
        let deepSeekKey = APIKeyStore.deepSeekKey
        if !deepSeekKey.isEmpty {
            // ✅ 真实 API
            providers.append(
                OpenAICompatibleProvider(
                    id: "deepseek-v3",
                    displayName: "DeepSeek-V3",
                    description: "DeepSeek 开源大模型，性价比极高，MoE 架构（真实 API）",
                    config: .deepSeek(apiKey: deepSeekKey, model: "deepseek-chat"),
                    architectureType: .moe,
                    modelInfo: ModelInfo(
                        family: "DeepSeek", parameterCount: "671B",
                        quantization: "N/A", fileSize: 0, contextLength: 64_000,
                        supportedLanguages: ["en", "zh"],
                        summary: "MoE 架构，671B 总参数但每次只激活 37B"
                    )
                )
            )
        } else {
            providers.append(
                MockRemoteProvider(
                    id: "deepseek-v3",
                    displayName: "DeepSeek-V3 (Mock)",
                    description: "模拟模式 — 设置 API Key 后启用真实 API",
                    family: "DeepSeek",
                    parameterCount: "671B",
                    architectureType: .moe
                )
            )
        }

        // ── 自定义 OpenAI 兼容 API ──
        let customURL = APIKeyStore.customBaseURL
        let customKey = APIKeyStore.customAPIKey
        let customModel = APIKeyStore.customModelId
        if !customURL.isEmpty, !customModel.isEmpty {
            providers.append(
                OpenAICompatibleProvider(
                    id: "custom-api",
                    displayName: "自定义模型 (\(customModel))",
                    description: "自定义 OpenAI 兼容 API: \(customURL)",
                    config: .custom(baseURL: customURL, apiKey: customKey, model: customModel),
                    architectureType: .dense,
                    modelInfo: ModelInfo(
                        family: "Custom", parameterCount: "未知",
                        quantization: "N/A", fileSize: 0, contextLength: 4096,
                        supportedLanguages: ["en", "zh"],
                        summary: "自定义 API 接入"
                    )
                )
            )
        }
    }

    // MARK: - 端侧模型注册

    /// 注册端侧模型：
    /// - 已下载的模型 → LlamaOnDeviceProvider（真实 llama.cpp 推理）
    /// - 未下载的模型 → LlamaOnDeviceProvider(localPath: nil)（显示未下载提示，chat 时抛出错误）
    private func registerOnDeviceProviders() {
        for model in GGUFModelCatalog.allModels {
            let localPath = ModelDownloadManager.shared.localPathIfDownloaded(model)
            providers.append(LlamaOnDeviceProvider(model: model, localPath: localPath))
        }
    }

    // MARK: - 刷新（API Key 变更后调用）

    /// 重新注册所有 Provider（API Key 变化后调用）
    func reloadProviders() {
        providers.removeAll()
        registerRemoteProviders()
        registerOnDeviceProviders()
    }

    // MARK: - 选择模型

    func selectModel(id: String) {
        selectedModelId = id
    }

    /// 获取远程模型列表
    var remoteProviders: [any AIModelProvider] {
        providers.filter { $0.providerType == .remote }
    }

    /// 获取端侧模型列表
    var onDeviceProviders: [any AIModelProvider] {
        providers.filter { $0.providerType == .onDevice }
    }
}

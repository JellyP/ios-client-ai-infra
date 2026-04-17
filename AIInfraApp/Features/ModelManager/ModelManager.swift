import Foundation

// MARK: - 模型管理器

/// 统一管理所有端侧模型提供者
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
        registerOnDeviceProviders()

        // 默认选中第一个模型
        if let first = providers.first {
            selectedModelId = first.id
        }
    }

    // MARK: - 端侧模型注册

    /// 注册端侧模型：
    /// - 已下载的模型 → LlamaOnDeviceProvider（真实 llama.cpp 推理）
    /// - 未下载的模型 → LlamaOnDeviceProvider(localPath: nil)（显示未下载提示）
    private func registerOnDeviceProviders() {
        for model in GGUFModelCatalog.allModels {
            let localPath = ModelDownloadManager.shared.localPathIfDownloaded(model)
            providers.append(LlamaOnDeviceProvider(model: model, localPath: localPath))
        }
    }

    // MARK: - 刷新

    /// 重新注册所有 Provider
    func reloadProviders() {
        providers.removeAll()
        registerOnDeviceProviders()
    }

    // MARK: - 选择模型

    func selectModel(id: String) {
        selectedModelId = id
    }
}

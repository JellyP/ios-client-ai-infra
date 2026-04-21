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

        // 模型下载完成时自动刷新 Provider 列表
        ModelDownloadManager.shared.onModelDownloadCompleted = { [weak self] in
            self?.reloadProviders()
        }
    }

    // MARK: - 端侧模型注册

    /// 注册端侧模型：
    /// - 已下载的模型 → LlamaOnDeviceProvider（真实 llama.cpp 推理）
    /// - 未下载的模型 → LlamaOnDeviceProvider(localPath: nil)（显示未下载提示）
    private func registerOnDeviceProviders() {
        for model in GGUFModelCatalog.allModels {
            let localPath = ModelDownloadManager.shared.localPathIfDownloaded(model)
            let mmprojPath = ModelDownloadManager.shared.mmprojPathIfDownloaded(model)
            if model.isMultimodal {
                print("[ModelManager] 注册多模态模型: \(model.displayName), localPath=\(localPath?.lastPathComponent ?? "nil"), mmprojPath=\(mmprojPath?.lastPathComponent ?? "nil")")
            }
            providers.append(LlamaOnDeviceProvider(model: model, localPath: localPath, mmprojLocalPath: mmprojPath))
        }
    }

    // MARK: - 刷新

    /// 重新注册所有 Provider（保留当前选中的模型）
    func reloadProviders() {
        let currentSelection = selectedModelId
        providers.removeAll()
        registerOnDeviceProviders()
        // 保留之前选中的模型
        if let currentSelection, providers.contains(where: { $0.id == currentSelection }) {
            selectedModelId = currentSelection
        }
    }

    // MARK: - 选择模型

    func selectModel(id: String) {
        selectedModelId = id
    }
}

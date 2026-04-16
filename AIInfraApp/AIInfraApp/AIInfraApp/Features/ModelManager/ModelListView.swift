import SwiftUI

// MARK: - 模型列表界面

/// 展示所有可用模型的详细信息，并提供下载入口和 API 配置
struct ModelListView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @State private var showAPISettings = false

    var body: some View {
        NavigationStack {
            List {
                // 设备信息
                Section {
                    deviceInfoCard
                } header: {
                    Text("设备信息")
                }

                // 快捷入口
                Section("管理") {
                    NavigationLink {
                        ModelDownloadStoreView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("模型商店")
                                    .font(.body)
                                Text("浏览和下载 GGUF 模型到手机")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.down.app.fill")
                                .foregroundStyle(.blue)
                        }
                    }

                    Button {
                        showAPISettings = true
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("API Key 设置")
                                    .font(.body)
                                Text("配置 OpenAI / DeepSeek API Key")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // 远程模型
                Section {
                    ForEach(modelManager.remoteProviders, id: \.id) { provider in
                        NavigationLink {
                            ModelDetailView(provider: provider)
                        } label: {
                            modelRow(provider)
                        }
                    }
                } header: {
                    Label("远程模型", systemImage: "cloud.fill")
                } footer: {
                    Text("远程模型通过 API 调用云端服务，需要网络和 API Key。名称含 (Mock) 表示尚未配置 API Key。")
                }

                // 端侧模型
                Section {
                    ForEach(modelManager.onDeviceProviders, id: \.id) { provider in
                        NavigationLink {
                            ModelDetailView(provider: provider)
                        } label: {
                            modelRow(provider)
                        }
                    }
                } header: {
                    Label("端侧模型", systemImage: "iphone")
                } footer: {
                    Text("端侧模型运行在设备本地，无需网络。需要先到「模型商店」下载 GGUF 模型文件。")
                }
            }
            .navigationTitle("模型库")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAPISettings) {
                APIKeySettingsView()
            }
        }
    }

    // MARK: - 设备信息

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("总内存", systemImage: "memorychip")
                    .font(.subheadline)
                Spacer()
                Text(MemoryUtils.formatBytes(MemoryUtils.totalMemory))
                    .font(.subheadline.monospacedDigit())
            }

            HStack {
                Label("已使用", systemImage: "chart.bar.fill")
                    .font(.subheadline)
                Spacer()
                Text(MemoryUtils.formatBytes(MemoryUtils.currentMemoryUsage))
                    .font(.subheadline.monospacedDigit())
            }

            HStack {
                Label("可运行模型", systemImage: "cpu")
                    .font(.subheadline)
                Spacer()
                Text(estimateRunnableModels())
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
    }

    private func estimateRunnableModels() -> String {
        let availableMB = MemoryUtils.totalMemory / 1_048_576
        if availableMB >= 8000 {
            return "≤3B (Q4)"
        } else if availableMB >= 6000 {
            return "≤2B (Q4)"
        } else if availableMB >= 4000 {
            return "≤1B (Q4)"
        } else {
            return "受限"
        }
    }

    // MARK: - 模型行

    private func modelRow(_ provider: any AIModelProvider) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(provider.displayName)
                    .font(.body.weight(.medium))

                Spacer()

                Text(provider.architectureType.rawValue)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(provider.architectureType == .moe ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
                    .foregroundStyle(provider.architectureType == .moe ? .orange : .purple)
                    .clipShape(Capsule())
            }

            Text(provider.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label(provider.modelInfo.parameterCount, systemImage: "number")
                    .font(.caption2)
                    .foregroundStyle(.blue)

                if provider.providerType == .onDevice {
                    Label(MemoryUtils.formatBytes(provider.modelInfo.fileSize), systemImage: "internaldrive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Label("\(provider.modelInfo.contextLength)", systemImage: "text.alignleft")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 模型详情页

struct ModelDetailView: View {
    let provider: any AIModelProvider

    var body: some View {
        List {
            Section("基本信息") {
                detailRow(title: "名称", value: provider.displayName)
                detailRow(title: "类型", value: provider.providerType.rawValue)
                detailRow(title: "架构", value: provider.architectureType.rawValue)
                detailRow(title: "模型家族", value: provider.modelInfo.family)
                detailRow(title: "参数量", value: provider.modelInfo.parameterCount)
                detailRow(title: "量化", value: provider.modelInfo.quantization)
                detailRow(title: "上下文长度", value: "\(provider.modelInfo.contextLength) tokens")
            }

            if provider.providerType == .onDevice {
                Section("存储信息") {
                    detailRow(title: "模型大小", value: MemoryUtils.formatBytes(provider.modelInfo.fileSize))
                    detailRow(title: "量化方案", value: provider.modelInfo.quantization)
                }
            }

            Section("支持语言") {
                Text(provider.modelInfo.supportedLanguages.joined(separator: ", "))
                    .font(.body)
            }

            Section("简介") {
                Text(provider.modelInfo.summary)
                    .font(.body)
            }
        }
        .navigationTitle(provider.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.medium))
        }
    }
}

// MARK: - API Key 设置界面

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modelManager: ModelManager

    @State private var openAIKey: String = APIKeyStore.openAIKey
    @State private var deepSeekKey: String = APIKeyStore.deepSeekKey
    @State private var customBaseURL: String = APIKeyStore.customBaseURL
    @State private var customAPIKey: String = APIKeyStore.customAPIKey
    @State private var customModelId: String = APIKeyStore.customModelId
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("配置 API Key 后，远程模型将使用真实 API 调用，而非模拟数据。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("OpenAI") {
                    SecureField("API Key (sk-...)", text: $openAIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Text("获取地址: platform.openai.com/api-keys")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section("DeepSeek") {
                    SecureField("API Key (sk-...)", text: $deepSeekKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Text("获取地址: platform.deepseek.com/api_keys\n价格: ¥1/百万 tokens，非常便宜，推荐入门使用")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section("自定义 OpenAI 兼容 API") {
                    TextField("Base URL (如 http://localhost:11434/v1)", text: $customBaseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("API Key (可选)", text: $customAPIKey)
                    TextField("Model ID (如 llama3.2)", text: $customModelId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Text("支持 Ollama、vLLM、LM Studio 等任何兼容 OpenAI 格式的服务")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section {
                    Button {
                        saveKeys()
                    } label: {
                        HStack {
                            Spacer()
                            if saved {
                                Label("已保存", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("保存并刷新")
                            }
                            Spacer()
                        }
                        .font(.headline)
                    }
                }
            }
            .navigationTitle("API Key 设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func saveKeys() {
        APIKeyStore.openAIKey = openAIKey
        APIKeyStore.deepSeekKey = deepSeekKey
        APIKeyStore.customBaseURL = customBaseURL
        APIKeyStore.customAPIKey = customAPIKey
        APIKeyStore.customModelId = customModelId

        // 刷新模型列表
        modelManager.reloadProviders()

        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { saved = false }
        }
    }
}

#Preview {
    ModelListView()
        .environmentObject(ModelManager())
}

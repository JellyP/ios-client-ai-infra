import SwiftUI

// MARK: - 模型列表界面

/// 展示所有可用端侧模型的详细信息，并提供下载入口
struct ModelListView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        NavigationStack {
            List {
                // 设备信息
                Section {
                    deviceInfoCard
                } header: {
                    Text(L10n.deviceInfo)
                }

                // 快捷入口
                Section(L10n.manage) {
                    NavigationLink {
                        ModelDownloadStoreView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(L10n.modelStore)
                                    .font(.body)
                                Text(L10n.modelStoreDesc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.down.app.fill")
                                .foregroundStyle(.blue)
                        }
                    }

                    // 语言切换
                    Picker(L10n.languageSetting, selection: $lang.currentLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }

                // 端侧模型
                Section {
                    ForEach(modelManager.providers, id: \.id) { provider in
                        NavigationLink {
                            ModelDetailView(provider: provider)
                        } label: {
                            modelRow(provider)
                        }
                    }
                } header: {
                    Label(L10n.onDeviceHeader, systemImage: "iphone")
                } footer: {
                    Text(L10n.onDeviceFooter)
                }
            }
            .navigationTitle(L10n.modelLibrary)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 设备信息

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.totalMemory, systemImage: "memorychip")
                    .font(.subheadline)
                Spacer()
                Text(MemoryUtils.formatBytes(MemoryUtils.totalMemory))
                    .font(.subheadline.monospacedDigit())
            }

            HStack {
                Label(L10n.usedMemory, systemImage: "chart.bar.fill")
                    .font(.subheadline)
                Spacer()
                Text(MemoryUtils.formatBytes(MemoryUtils.currentMemoryUsage))
                    .font(.subheadline.monospacedDigit())
            }

            HStack {
                Label(L10n.runnableModels, systemImage: "cpu")
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
            return L10n.limited
        }
    }

    // MARK: - 模型行

    private func modelRow(_ provider: any AIModelProvider) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(provider.displayName)
                    .font(.body.weight(.medium))

                // 下载状态
                if let model = GGUFModelCatalog.allModels.first(where: { $0.id == provider.id }) {
                    if ModelDownloadManager.shared.isModelDownloaded(model) {
                        Text(L10n.downloaded)
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Text(L10n.notDownloaded)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                Text(provider.architectureType.rawValue)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(provider.architectureType == .moe ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
                    .foregroundStyle(provider.architectureType == .moe ? .orange : .purple)
                    .clipShape(Capsule())
            }

            Text(lang.currentLanguage == .english ? provider.descriptionEN : provider.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label(provider.modelInfo.parameterCount, systemImage: "number")
                    .font(.caption2)
                    .foregroundStyle(.blue)

                Label(MemoryUtils.formatBytes(provider.modelInfo.fileSize), systemImage: "internaldrive")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

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
    @EnvironmentObject private var lang: LanguageManager
    let provider: any AIModelProvider

    var body: some View {
        List {
            Section(L10n.basicInfo) {
                detailRow(title: L10n.name, value: provider.displayName)
                detailRow(title: L10n.architecture, value: provider.architectureType.rawValue)
                detailRow(title: L10n.modelFamily, value: provider.modelInfo.family)
                detailRow(title: L10n.paramCount, value: provider.modelInfo.parameterCount)
                detailRow(title: L10n.quantization, value: provider.modelInfo.quantization)
                detailRow(title: L10n.contextLength, value: "\(provider.modelInfo.contextLength) tokens")
            }

            Section(L10n.storageInfo) {
                detailRow(title: L10n.modelSize, value: MemoryUtils.formatBytes(provider.modelInfo.fileSize))
                detailRow(title: L10n.quantization, value: provider.modelInfo.quantization)
            }

            Section(L10n.languages) {
                Text(provider.modelInfo.supportedLanguages.joined(separator: ", "))
                    .font(.body)
            }

            Section(L10n.summary) {
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

#Preview {
    ModelListView()
        .environmentObject(ModelManager())
}

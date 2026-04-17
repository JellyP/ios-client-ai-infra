import SwiftUI

// MARK: - 模型列表界面

/// 展示所有可用端侧模型的详细信息，并提供下载入口
struct ModelListView: View {
    @EnvironmentObject private var modelManager: ModelManager

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
                    Label("端侧模型", systemImage: "iphone")
                } footer: {
                    Text("端侧模型运行在设备本地，无需网络。需要先到「模型商店」下载 GGUF 模型文件。")
                }
            }
            .navigationTitle("模型库")
            .navigationBarTitleDisplayMode(.inline)
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

                // 下载状态
                if let model = GGUFModelCatalog.allModels.first(where: { $0.id == provider.id }) {
                    if ModelDownloadManager.shared.isModelDownloaded(model) {
                        Text("已下载")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Text("未下载")
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

            Text(provider.description)
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
    let provider: any AIModelProvider

    var body: some View {
        List {
            Section("基本信息") {
                detailRow(title: "名称", value: provider.displayName)
                detailRow(title: "架构", value: provider.architectureType.rawValue)
                detailRow(title: "模型家族", value: provider.modelInfo.family)
                detailRow(title: "参数量", value: provider.modelInfo.parameterCount)
                detailRow(title: "量化", value: provider.modelInfo.quantization)
                detailRow(title: "上下文长度", value: "\(provider.modelInfo.contextLength) tokens")
            }

            Section("存储信息") {
                detailRow(title: "模型大小", value: MemoryUtils.formatBytes(provider.modelInfo.fileSize))
                detailRow(title: "量化方案", value: provider.modelInfo.quantization)
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

#Preview {
    ModelListView()
        .environmentObject(ModelManager())
}

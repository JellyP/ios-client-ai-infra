import SwiftUI

// MARK: - 模型下载商店界面

/// App 内的模型下载页面，用户可以直接在这里浏览和下载模型
struct ModelDownloadStoreView: View {
    @StateObject private var downloadManager = ModelDownloadManager.shared
    @State private var selectedTag: ModelTag?

    private let catalog = GGUFModelCatalog.allModels

    var body: some View {
        List {
            // 存储空间概览
            storageSection

            // 推荐模型
            if selectedTag == nil {
                recommendedSection
            }

            // 标签筛选
            tagFilterSection

            // 模型列表
            modelListSection
        }
        .navigationTitle("模型商店")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            downloadManager.refreshDownloadedModels()
        }
    }

    // MARK: - 存储概览

    private var storageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("已下载模型", systemImage: "internaldrive")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(downloadManager.downloadedModels.count) 个")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("占用空间")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MemoryUtils.formatBytes(downloadManager.totalStorageUsed))
                        .font(.caption.monospacedDigit().weight(.medium))
                }

                Text("模型文件下载到 App 本地存储，卸载 App 会同时删除。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - 推荐

    private var recommendedSection: some View {
        Section("推荐首次下载") {
            ForEach(GGUFModelCatalog.recommendedForFirstTime) { model in
                modelRow(model, highlight: true)
            }
        }
    }

    // MARK: - 标签筛选

    private var tagFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tagButton(nil, label: "全部")
                    ForEach(ModelTag.allCases, id: \.self) { tag in
                        tagButton(tag, label: tag.rawValue)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private func tagButton(_ tag: ModelTag?, label: String) -> some View {
        Button {
            withAnimation { selectedTag = tag }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedTag == tag ? Color.blue : Color(.systemGray5))
                .foregroundStyle(selectedTag == tag ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 模型列表

    private var modelListSection: some View {
        Section("所有模型（按大小排序）") {
            ForEach(filteredModels) { model in
                modelRow(model, highlight: false)
            }
        }
    }

    private var filteredModels: [DownloadableModel] {
        let sorted = GGUFModelCatalog.sortedBySize
        if let tag = selectedTag {
            return sorted.filter { $0.tags.contains(tag) }
        }
        return sorted
    }

    // MARK: - 模型行

    private func modelRow(_ model: DownloadableModel, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：名称 + 标签
            HStack {
                Text(model.displayName)
                    .font(.body.weight(.semibold))

                Text(model.parameterCount)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())

                Text(model.quantization)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())

                Spacer()

                Text(model.formattedSize)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // 第二行：描述
            Text(model.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // 第三行：标签
            HStack(spacing: 4) {
                ForEach(model.tags, id: \.self) { tag in
                    Text(tag.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tagColor(tag).opacity(0.1))
                        .foregroundStyle(tagColor(tag))
                        .clipShape(Capsule())
                }

                Spacer()

                Text("ctx: \(model.contextLength)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 第四行：下载状态 / 操作按钮
            downloadActionRow(model)
        }
        .padding(.vertical, 4)
        .listRowBackground(highlight ? Color.blue.opacity(0.03) : nil)
    }

    private func tagColor(_ tag: ModelTag) -> Color {
        switch tag {
        case .recommended: return .blue
        case .bestValue: return .green
        case .lightweight: return .mint
        case .powerful: return .orange
        case .chinese: return .red
        case .english: return .indigo
        case .code: return .purple
        case .reasoning: return .teal
        }
    }

    // MARK: - 下载操作行

    @ViewBuilder
    private func downloadActionRow(_ model: DownloadableModel) -> some View {
        let state = downloadManager.downloadStates[model.id]

        switch state {
        case .downloading(let progress):
            VStack(spacing: 4) {
                ProgressView(value: progress)
                HStack {
                    Text("下载中 \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("暂停") {
                        downloadManager.pauseDownload(model.id)
                    }
                    .font(.caption2)
                }
            }

        case .paused:
            HStack {
                Text("已暂停")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Button("继续") {
                    downloadManager.resumeDownload(model.id)
                }
                .font(.caption)
                Button("取消") {
                    downloadManager.cancelDownload(model.id)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

        case .completed:
            HStack {
                Label("已下载", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Button(role: .destructive) {
                    downloadManager.deleteModel(model)
                } label: {
                    Text("删除")
                        .font(.caption)
                }
            }

        case .failed(let error):
            HStack {
                Text("下载失败: \(error)")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                Spacer()
                Button("重试") {
                    downloadManager.downloadModel(model)
                }
                .font(.caption)
            }

        case nil:
            // 未下载
            Button {
                downloadManager.downloadModel(model)
            } label: {
                HStack {
                    Spacer()
                    Label("下载 (\(model.formattedSize))", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        ModelDownloadStoreView()
    }
}

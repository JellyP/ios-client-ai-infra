import SwiftUI

// MARK: - 模型下载商店界面

/// App 内的模型下载页面，用户可以直接在这里浏览和下载模型
struct ModelDownloadStoreView: View {
    @StateObject private var downloadManager = ModelDownloadManager.shared
    @EnvironmentObject private var lang: LanguageManager
    @State private var selectedTag: ModelTag?
    @State private var selectedMirror: DownloadMirror = APIKeyStore.downloadMirror

    private let catalog = GGUFModelCatalog.allModels

    var body: some View {
        List {
            // 下载源选择
            mirrorSection

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
        .navigationTitle(L10n.modelStore)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            downloadManager.refreshDownloadedModels()
        }
    }

    // MARK: - 下载源选择

    private var mirrorSection: some View {
        Section {
            Picker(L10n.downloadSource, selection: $selectedMirror) {
                ForEach(DownloadMirror.allCases, id: \.self) { mirror in
                    VStack(alignment: .leading) {
                        Text(mirror.displayName)
                    }
                    .tag(mirror)
                }
            }
            .onChange(of: selectedMirror) {
                APIKeyStore.downloadMirror = selectedMirror
            }

            Text(selectedMirror.description)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } header: {
            Text(L10n.downloadSource)
        }
    }

    // MARK: - 存储概览

    private var storageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(L10n.downloadedModels, systemImage: "internaldrive")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(downloadManager.downloadedModels.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(L10n.storageUsed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MemoryUtils.formatBytes(downloadManager.totalStorageUsed))
                        .font(.caption.monospacedDigit().weight(.medium))
                }

                Text(L10n.storageNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - 推荐

    private var recommendedSection: some View {
        Section(L10n.recommendedFirst) {
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
                    tagButton(nil, label: L10n.selectAll)
                    ForEach(ModelTag.allCases, id: \.self) { tag in
                        tagButton(tag, label: tag.localizedName)
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
        Section(L10n.allModelsBySize) {
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
            Text(model.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // 第三行：标签
            HStack(spacing: 4) {
                ForEach(model.tags, id: \.self) { tag in
                    Text(tag.localizedName)
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
        case .imageClassification: return .orange
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
                    Text("\(L10n.downloading) \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.pauseBtn) {
                        downloadManager.pauseDownload(model.id)
                    }
                    .font(.caption2)
                }
            }

        case .paused:
            HStack {
                Text(L10n.paused)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Button(L10n.resumeBtn) {
                    downloadManager.resumeDownload(model.id)
                }
                .font(.caption)
                Button(L10n.cancelBtn) {
                    downloadManager.cancelDownload(model.id)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

        case .completed:
            VStack(spacing: 4) {
                HStack {
                    Label(L10n.downloaded, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Button(role: .destructive) {
                        downloadManager.deleteModel(model)
                    } label: {
                        Text(L10n.deleteBtn)
                            .font(.caption)
                    }
                }

                // 多模态模型：显示 mmproj 下载状态
                if model.isMultimodal {
                    let mmprojId = model.id + "-mmproj"
                    let mmprojState = downloadManager.downloadStates[mmprojId]
                    let mmprojDownloaded = downloadManager.isMmprojDownloaded(model)

                    if mmprojDownloaded {
                        HStack {
                            Label("mmproj " + L10n.downloaded, systemImage: "eye.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                    } else if case .downloading(let progress) = mmprojState {
                        HStack {
                            Text("mmproj \(L10n.downloading)")
                                .font(.caption2)
                            ProgressView(value: progress)
                                .frame(width: 80)
                        }
                    } else {
                        HStack {
                            Text("mmproj \(L10n.notDownloaded)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                downloadManager.downloadMmproj(model)
                            } label: {
                                Text(L10n.downloadTestImages)
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

        case .failed(let error):
            HStack {
                Text("\(L10n.downloadFailed): \(error)")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                Spacer()
                Button(L10n.retryBtn) {
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
                    Label(L10n.downloadBtn(model.formattedSize), systemImage: "arrow.down.circle.fill")
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

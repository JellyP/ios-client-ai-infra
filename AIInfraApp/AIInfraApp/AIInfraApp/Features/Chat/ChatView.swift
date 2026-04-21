import SwiftUI
import Textual
import PhotosUI

// MARK: - 聊天界面

/// 主聊天界面，支持切换模型进行对话，保存历史记录
struct ChatView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var historyStore = ChatHistoryStore.shared

    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isGenerating = false
    @State private var currentResponse = ""
    @State private var lastMetrics: GenerationMetrics?
    @State private var showMetrics = false
    @State private var showModelPicker = false
    @State private var showHistory = false
    @State private var currentSessionId: UUID = UUID()
    @FocusState private var isInputFocused: Bool

    // 图片选择相关
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImagePreview: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 模型选择器
                modelSelectorBar

                Divider()

                // 消息列表
                messageList

                // 性能指标（可折叠）
                if showMetrics, let metrics = lastMetrics {
                    metricsBar(metrics)
                }

                Divider()

                // 输入区域
                inputArea
            }
            .navigationTitle(L10n.chatTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showMetrics.toggle()
                        } label: {
                            Image(systemName: showMetrics ? "chart.bar.fill" : "chart.bar")
                        }
                        Button {
                            startNewSession()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                ChatHistorySheet(
                    historyStore: historyStore,
                    onSelect: { session in
                        loadSession(session)
                        showHistory = false
                    }
                )
            }
        }
    }

    // MARK: - 新建 / 加载会话

    private func startNewSession() {
        saveCurrentSessionIfNeeded()
        messages.removeAll()
        currentResponse = ""
        lastMetrics = nil
        currentSessionId = UUID()
    }

    private func loadSession(_ session: ChatSession) {
        saveCurrentSessionIfNeeded()
        messages = session.messages
        currentSessionId = session.id
        currentResponse = ""
        lastMetrics = nil
        // 切换到对应模型
        if modelManager.selectedModelId != session.modelId {
            modelManager.selectModel(id: session.modelId)
        }
    }

    private func saveCurrentSessionIfNeeded() {
        guard !messages.isEmpty,
              let modelId = modelManager.selectedModelId else { return }

        let title = messages.first(where: { $0.role == .user })?.content.prefix(30)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? L10n.conversation

        var session = ChatSession(id: currentSessionId, title: String(title), modelId: modelId)
        session.messages = messages
        session.updatedAt = Date()
        historyStore.save(session)
    }

    /// 缩放图片到最大尺寸（防止大图导致 Metal GPU crash / OOM）
    #if canImport(UIKit)
    static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    // MARK: - 模型选择器

    private var modelSelectorBar: some View {
        Button {
            showModelPicker = true
        } label: {
            HStack {
                Circle()
                    .fill(providerTypeColor)
                    .frame(width: 8, height: 8)

                Text(modelManager.selectedProvider?.displayName ?? L10n.selectModel)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showModelPicker) {
            modelPickerSheet
        }
    }

    private var providerTypeColor: Color {
        if modelManager.selectedProvider != nil {
            return .green
        }
        return .gray
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        emptyStateView
                    }

                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    // 正在生成的回复
                    if isGenerating || !currentResponse.isEmpty {
                        streamingResponseView
                            .id("streaming")
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: messages.count) {
                withAnimation {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: currentResponse) {
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.selectModelStartChat)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(L10n.compareHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var streamingResponseView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "cpu")
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 24, height: 24)
                .background(Color.purple.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                StructuredText(markdown: currentResponse, syntaxExtensions: [.math])
                    .textual.structuredTextStyle(.gitHub)
                    .textual.textSelection(.enabled)

                if isGenerating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(L10n.generating)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 性能指标

    private func metricsBar(_ metrics: GenerationMetrics) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                metricItem(
                    title: L10n.ttft,
                    value: String(format: "%.0fms", metrics.timeToFirstToken * 1000)
                )
                metricItem(
                    title: L10n.speed,
                    value: String(format: "%.1f t/s", metrics.decodeTokensPerSecond)
                )
                metricItem(
                    title: L10n.totalTime,
                    value: String(format: "%.1fs", metrics.totalTime)
                )
                metricItem(
                    title: L10n.genTokens,
                    value: "\(metrics.totalGeneratedTokens)"
                )
                metricItem(
                    title: L10n.memory,
                    value: MemoryUtils.formatBytes(metrics.peakMemoryUsage)
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }

    private func metricItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }

    // MARK: - 输入区域

    private var inputArea: some View {
        VStack(spacing: 6) {
            // 图片预览区（已选择图片时显示）
            if let preview = selectedImagePreview {
                HStack {
                    preview
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.imageAttached)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                        if let data = selectedImageData {
                            Text(MemoryUtils.formatBytes(Int64(data.count)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        selectedImageData = nil
                        selectedImagePreview = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // 图片选择按钮
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                        .frame(width: 36, height: 36)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        guard let newItem else { return }
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            #if canImport(UIKit)
                            if let uiImage = UIImage(data: data) {
                                // 缩放到最大 384x384 并转为 JPEG
                                // 视觉模型内部会再 resize，过大的图只会增加 token 数导致很慢
                                let resized = Self.resizeImage(uiImage, maxDimension: 384)
                                selectedImageData = resized.jpegData(compressionQuality: 0.85)
                                selectedImagePreview = Image(uiImage: resized)
                            } else {
                                selectedImageData = data
                            }
                            #else
                            selectedImageData = data
                            #endif
                        }
                    }
                }

                TextField(L10n.inputPlaceholder, text: $inputText, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    if isGenerating {
                        cancelGeneration()
                    } else {
                        sendMessage()
                    }
                } label: {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(isGenerating ? .red : .blue)
                        .frame(width: 36, height: 36)
                }
                .disabled(!isGenerating && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 模型选择面板

    private var modelPickerSheet: some View {
        NavigationStack {
            List {
                Section(L10n.onDeviceModels) {
                    ForEach(modelManager.providers, id: \.id) { provider in
                        modelRow(provider)
                    }
                }
            }
            .navigationTitle(L10n.selectModel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) {
                        showModelPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func modelRow(_ provider: any AIModelProvider) -> some View {
        Button {
            modelManager.selectModel(id: provider.id)
            showModelPicker = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(provider.displayName)
                            .font(.body.weight(.medium))

                        Text(provider.architectureType.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(provider.architectureType == .moe ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                            .clipShape(Capsule())

                        // 下载状态标识
                        downloadBadge(for: provider)
                    }

                    Text(lang.currentLanguage == .english ? provider.descriptionEN : provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(provider.modelInfo.parameterCount)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.blue)

                        Text(MemoryUtils.formatBytes(provider.modelInfo.fileSize))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if modelManager.selectedModelId == provider.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 端侧模型下载状态标识
    @ViewBuilder
    private func downloadBadge(for provider: any AIModelProvider) -> some View {
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
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = selectedImageData != nil

        // 需要有文本或图片才能发送
        guard !text.isEmpty || hasImage else { return }

        isInputFocused = false

        // 构建消息（可能附带图片）
        let imageData: [Data]? = selectedImageData != nil ? [selectedImageData!] : nil
        let messageContent = text.isEmpty ? (L10n.imageAttached) : text
        let userMessage = ChatMessage(role: .user, content: messageContent, imageData: imageData)
        messages.append(userMessage)

        // 清空输入
        inputText = ""
        selectedImageData = nil
        selectedImagePreview = nil
        selectedPhotoItem = nil
        currentResponse = ""

        guard let provider = modelManager.selectedProvider else { return }

        isGenerating = true

        Task {
            // 如果模型未加载，先加载
            if provider.state == .unloaded {
                try? await provider.load()
            }

            let stream = provider.chat(messages: messages, config: .default)

            do {
                for try await token in stream {
                    currentResponse += token.text

                    if token.isFinished {
                        lastMetrics = token.metrics
                    }
                }
            } catch {
                currentResponse += "\n[\(L10n.error): \(error.localizedDescription)]"
            }

            // 将完成的回复添加到消息列表
            if !currentResponse.isEmpty {
                let assistantMessage = ChatMessage(role: .assistant, content: currentResponse)
                messages.append(assistantMessage)
                currentResponse = ""
            }

            isGenerating = false

            // 自动保存当前会话
            saveCurrentSessionIfNeeded()
        }
    }

    private func cancelGeneration() {
        modelManager.selectedProvider?.cancelGeneration()
        isGenerating = false

        if !currentResponse.isEmpty {
            let assistantMessage = ChatMessage(role: .assistant, content: currentResponse + " [\(L10n.cancelled)]")
            messages.append(assistantMessage)
            currentResponse = ""
        }

        saveCurrentSessionIfNeeded()
    }
}

// MARK: - 历史记录面板

struct ChatHistorySheet: View {
    @ObservedObject var historyStore: ChatHistoryStore
    let onSelect: (ChatSession) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.sessions.isEmpty {
                    ContentUnavailableView(
                        L10n.noHistory,
                        systemImage: "clock",
                        description: Text(L10n.autoSaveHint)
                    )
                } else {
                    List {
                        ForEach(historyStore.sessions) { session in
                            Button { onSelect(session) } label: {
                                sessionRow(session)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { historyStore.sessions[$0].id }
                            ids.forEach { historyStore.delete(id: $0) }
                        }
                    }
                }
            }
            .navigationTitle(L10n.chatHistory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sessionRow(_ session: ChatSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(session.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
                Text(session.modelId)
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                Text("\(session.messages.count)\(L10n.messages)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 消息气泡视图

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                assistantBubble
            } else {
                userBubble
            }
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                // 显示附带的图片
                if let imageDataList = message.imageData {
                    ForEach(imageDataList.indices, id: \.self) { i in
                        #if canImport(UIKit)
                        if let uiImage = UIImage(data: imageDataList[i]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200, maxHeight: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        #endif
                    }
                }
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "cpu")
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 24, height: 24)
                .background(Color.purple.opacity(0.1))
                .clipShape(Circle())

            StructuredText(markdown: message.content, syntaxExtensions: [.math])
                .textual.structuredTextStyle(.gitHub)
                .textual.textSelection(.enabled)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(ModelManager())
        .environmentObject(LanguageManager.shared)
}

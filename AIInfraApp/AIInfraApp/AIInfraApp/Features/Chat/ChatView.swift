import SwiftUI

// MARK: - 聊天界面

/// 主聊天界面，支持切换模型进行对话
struct ChatView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isGenerating = false
    @State private var currentResponse = ""
    @State private var lastMetrics: GenerationMetrics?
    @State private var showMetrics = false
    @State private var showModelPicker = false

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
            .navigationTitle("AI 对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMetrics.toggle()
                    } label: {
                        Image(systemName: showMetrics ? "chart.bar.fill" : "chart.bar")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("清空") {
                        messages.removeAll()
                        currentResponse = ""
                        lastMetrics = nil
                    }
                }
            }
        }
    }

    // MARK: - 模型选择器

    private var modelSelectorBar: some View {
        Button {
            showModelPicker = true
        } label: {
            HStack {
                Circle()
                    .fill(providerTypeColor)
                    .frame(width: 8, height: 8)

                Text(modelManager.selectedProvider?.displayName ?? "选择模型")
                    .font(.subheadline.weight(.medium))

                if let provider = modelManager.selectedProvider {
                    Text(provider.providerType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(providerTypeColor.opacity(0.15))
                        .clipShape(Capsule())
                }

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
        switch modelManager.selectedProvider?.providerType {
        case .remote: return .blue
        case .onDevice: return .green
        case nil: return .gray
        }
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
            Text("选择模型，开始对话")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("你可以对比远程模型和端侧模型的回答质量与速度")
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
                Text(currentResponse)
                    .font(.body)
                    .textSelection(.enabled)

                if isGenerating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("生成中...")
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
                    title: "首字延迟",
                    value: String(format: "%.0fms", metrics.timeToFirstToken * 1000)
                )
                metricItem(
                    title: "生成速度",
                    value: String(format: "%.1f t/s", metrics.decodeTokensPerSecond)
                )
                metricItem(
                    title: "总耗时",
                    value: String(format: "%.1fs", metrics.totalTime)
                )
                metricItem(
                    title: "生成Token",
                    value: "\(metrics.totalGeneratedTokens)"
                )
                metricItem(
                    title: "内存",
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
        HStack(alignment: .bottom, spacing: 8) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
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
                    .font(.title2)
                    .foregroundStyle(isGenerating ? .red : .blue)
            }
            .disabled(!isGenerating && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - 模型选择面板

    private var modelPickerSheet: some View {
        NavigationStack {
            List {
                Section("远程模型") {
                    ForEach(modelManager.remoteProviders, id: \.id) { provider in
                        modelRow(provider)
                    }
                }

                Section("端侧模型") {
                    ForEach(modelManager.onDeviceProviders, id: \.id) { provider in
                        modelRow(provider)
                    }
                }
            }
            .navigationTitle("选择模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
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
                    }

                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(provider.modelInfo.parameterCount)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.blue)

                        if provider.providerType == .onDevice {
                            Text(MemoryUtils.formatBytes(provider.modelInfo.fileSize))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
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

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
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
                currentResponse += "\n[错误: \(error.localizedDescription)]"
            }

            // 将完成的回复添加到消息列表
            if !currentResponse.isEmpty {
                let assistantMessage = ChatMessage(role: .assistant, content: currentResponse)
                messages.append(assistantMessage)
                currentResponse = ""
            }

            isGenerating = false
        }
    }

    private func cancelGeneration() {
        modelManager.selectedProvider?.cancelGeneration()
        isGenerating = false

        if !currentResponse.isEmpty {
            let assistantMessage = ChatMessage(role: .assistant, content: currentResponse + " [已取消]")
            messages.append(assistantMessage)
            currentResponse = ""
        }
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
            Text(message.content)
                .font(.body)
                .padding(12)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
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

            Text(message.content)
                .font(.body)
                .textSelection(.enabled)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(ModelManager())
}

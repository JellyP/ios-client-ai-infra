import SwiftUI

// MARK: - Benchmark 测评界面

/// 模型性能对比测评界面
struct BenchmarkView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @State private var selectedTestCases: Set<UUID> = []
    @State private var selectedModels: Set<String> = []
    @State private var results: [BenchmarkResult] = []
    @State private var isRunning = false
    @State private var currentTask = ""
    @State private var progress: Double = 0
    @State private var showResults = false

    private let testCases = BenchmarkTestCase.standardTestSuite

    var body: some View {
        NavigationStack {
            List {
                // 状态概览
                statusSection

                // 模型选择
                modelSelectionSection

                // 测试用例选择
                testCaseSelectionSection

                // 运行按钮
                runSection

                // 结果展示
                if !results.isEmpty {
                    resultSection
                }
            }
            .navigationTitle("模型测评")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 状态概览

    private var statusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text("设备信息")
                        .font(.subheadline.weight(.medium))
                    Text("内存: \(MemoryUtils.formatBytes(MemoryUtils.totalMemory))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("已用: \(MemoryUtils.formatBytes(MemoryUtils.currentMemoryUsage))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("已选模型: \(selectedModels.count)")
                        .font(.caption)
                    Text("已选用例: \(selectedTestCases.count)")
                        .font(.caption)
                }
            }

            if isRunning {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTask)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: progress)
                }
            }
        }
    }

    // MARK: - 模型选择

    private var modelSelectionSection: some View {
        Section("选择对比模型") {
            ForEach(modelManager.providers, id: \.id) { provider in
                Button {
                    if selectedModels.contains(provider.id) {
                        selectedModels.remove(provider.id)
                    } else {
                        selectedModels.insert(provider.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(provider.displayName)
                                    .font(.body)

                                Text(provider.providerType.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(provider.providerType == .remote ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                                    .clipShape(Capsule())

                                Text(provider.architectureType.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(provider.architectureType == .moe ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            Text(provider.modelInfo.parameterCount)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: selectedModels.contains(provider.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedModels.contains(provider.id) ? .blue : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 测试用例选择

    private var testCaseSelectionSection: some View {
        Section("选择测试用例") {
            Button("全选") {
                selectedTestCases = Set(testCases.map(\.id))
            }
            .font(.caption)

            ForEach(testCases) { testCase in
                Button {
                    if selectedTestCases.contains(testCase.id) {
                        selectedTestCases.remove(testCase.id)
                    } else {
                        selectedTestCases.insert(testCase.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(testCase.name)
                                .font(.body)
                            Text(testCase.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selectedTestCases.contains(testCase.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTestCases.contains(testCase.id) ? .blue : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 运行

    private var runSection: some View {
        Section {
            Button {
                Task { await runBenchmark() }
            } label: {
                HStack {
                    Spacer()
                    if isRunning {
                        ProgressView()
                            .padding(.trailing, 4)
                        Text("测试中...")
                    } else {
                        Image(systemName: "play.fill")
                        Text("开始测评")
                    }
                    Spacer()
                }
                .font(.headline)
                .padding(.vertical, 4)
            }
            .disabled(isRunning || selectedModels.isEmpty || selectedTestCases.isEmpty)
        }
    }

    // MARK: - 结果展示

    private var resultSection: some View {
        Section("测评结果") {
            // 按测试用例分组展示
            ForEach(testCases.filter { selectedTestCases.contains($0.id) }) { testCase in
                let caseResults = results.filter { $0.testCaseId == testCase.id }
                if !caseResults.isEmpty {
                    DisclosureGroup {
                        ForEach(caseResults) { result in
                            resultRow(result)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(testCase.name)
                                .font(.subheadline.weight(.medium))
                            Text("\(caseResults.count) 个模型已完成")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func resultRow(_ result: BenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.modelName)
                    .font(.subheadline.weight(.medium))

                Text(result.providerType.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(result.providerType == .remote ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                    .clipShape(Capsule())
            }

            // 性能指标
            HStack(spacing: 12) {
                miniMetric(label: "首字延迟", value: String(format: "%.0fms", result.metrics.timeToFirstToken * 1000))
                miniMetric(label: "速度", value: String(format: "%.1ft/s", result.metrics.decodeTokensPerSecond))
                miniMetric(label: "总耗时", value: String(format: "%.1fs", result.metrics.totalTime))
            }

            // 回复预览
            Text(result.response.prefix(100) + (result.response.count > 100 ? "..." : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }

    private func miniMetric(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }

    // MARK: - 运行逻辑

    private func runBenchmark() async {
        isRunning = true
        results.removeAll()

        let selectedTests = testCases.filter { selectedTestCases.contains($0.id) }
        let totalTasks = selectedTests.count * selectedModels.count
        var completedTasks = 0

        for testCase in selectedTests {
            for modelId in selectedModels {
                guard let provider = modelManager.providers.first(where: { $0.id == modelId }) else { continue }

                currentTask = "正在测试 \(provider.displayName) - \(testCase.name)"

                // 加载模型
                if provider.state == .unloaded {
                    try? await provider.load()
                }

                // 运行测试
                let messages = [ChatMessage(role: .user, content: testCase.prompt)]
                let stream = provider.chat(messages: messages, config: .default)

                var response = ""
                var finalMetrics: GenerationMetrics?

                do {
                    for try await token in stream {
                        response += token.text
                        if token.isFinished {
                            finalMetrics = token.metrics
                        }
                    }
                } catch {
                    response = "[错误: \(error.localizedDescription)]"
                }

                if let metrics = finalMetrics {
                    let result = BenchmarkResult(
                        testCaseId: testCase.id,
                        testCaseName: testCase.name,
                        modelName: provider.displayName,
                        providerType: provider.providerType,
                        architectureType: provider.architectureType,
                        metrics: metrics,
                        response: response
                    )
                    results.append(result)
                }

                completedTasks += 1
                progress = Double(completedTasks) / Double(totalTasks)
            }
        }

        isRunning = false
        currentTask = "测评完成"
    }
}

#Preview {
    BenchmarkView()
        .environmentObject(ModelManager())
}

import SwiftUI
import Textual

// MARK: - Benchmark 测评界面

/// 模型性能对比测评界面
struct BenchmarkView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @EnvironmentObject private var lang: LanguageManager
    @State private var selectedTestCases: Set<UUID> = []
    @State private var selectedModels: [String] = []
    @State private var results: [BenchmarkResult] = []
    @State private var isRunning = false
    @State private var currentModelName = ""
    @State private var currentTask = ""
    @State private var modelIndex = 0
    @State private var modelTotal = 0
    @State private var progress: Double = 0

    private var testCases: [BenchmarkTestCase] {
        lang.currentLanguage == .english ? BenchmarkTestCase.standardTestSuiteEN : BenchmarkTestCase.standardTestSuite
    }

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
            .navigationTitle(L10n.benchmarkTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 状态概览

    private var statusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text(L10n.deviceInfo)
                        .font(.subheadline.weight(.medium))
                    Text("\(L10n.memoryLabel): \(MemoryUtils.formatBytes(MemoryUtils.totalMemory))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(L10n.usedLabel): \(MemoryUtils.formatBytes(MemoryUtils.currentMemoryUsage))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(L10n.selectedModels): \(selectedModels.count)")
                        .font(.caption)
                    Text("\(L10n.selectedCases): \(selectedTestCases.count)")
                        .font(.caption)
                }
            }

            if isRunning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("[\(modelIndex)/\(modelTotal)] \(currentModelName)")
                        .font(.caption.weight(.medium))
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
        Section {
            ForEach(modelManager.providers, id: \.id) { provider in
                Button {
                    toggleModel(provider.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(provider.displayName)
                                    .font(.body)

                                Text(provider.architectureType.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(provider.architectureType == .moe ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
                                    .clipShape(Capsule())

                                if let model = GGUFModelCatalog.allModels.first(where: { $0.id == provider.id }) {
                                    if ModelDownloadManager.shared.isModelDownloaded(model) {
                                        Text(L10n.downloaded)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.12))
                                            .clipShape(Capsule())
                                    } else {
                                        Text(L10n.notDownloaded)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color(.systemGray5))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            Text(provider.modelInfo.parameterCount)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let idx = selectedModels.firstIndex(of: provider.id) {
                            ZStack {
                                Circle().fill(.blue).frame(width: 22, height: 22)
                                Text("\(idx + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(L10n.selectModelsHeader)
        } footer: {
            Text(L10n.selectModelsFooter)
                .font(.caption2)
        }
    }

    private func toggleModel(_ id: String) {
        if let idx = selectedModels.firstIndex(of: id) {
            selectedModels.remove(at: idx)
        } else {
            selectedModels.append(id)
        }
    }

    // MARK: - 测试用例选择

    private var testCaseSelectionSection: some View {
        Section {
            HStack {
                Button(L10n.selectAll) {
                    selectedTestCases = Set(testCases.map(\.id))
                }
                .font(.caption)
                .buttonStyle(.borderless)
                Button(L10n.deselectAll) {
                    selectedTestCases.removeAll()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.borderless)
            }

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
        } header: {
            Text(L10n.selectTestCases)
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
                        Text(L10n.testing)
                    } else {
                        Image(systemName: "play.fill")
                        Text(L10n.startBenchmark)
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
        Group {
            // 多模型对比表（核心）
            if modelNamesInResults.count > 1 {
                Section {
                    compareOverview
                } header: {
                    Text(L10n.overallComparison)
                }

                Section {
                    perTestCaseComparison
                } header: {
                    Text(L10n.perItemComparison)
                }
            }

            // 按模型分组详情
            Section {
                ForEach(modelNamesInResults, id: \.self) { modelName in
                    let modelResults = results.filter { $0.modelName == modelName }
                    DisclosureGroup {
                        ForEach(modelResults) { result in
                            resultRow(result)
                        }
                    } label: {
                        modelGroupHeader(modelName: modelName, results: modelResults)
                    }
                }
            } header: {
                Text(L10n.detailedResults)
            }
        }
    }

    // MARK: - 综合对比总览

    private var compareOverview: some View {
        let models = modelNamesInResults
        let grouped = Dictionary(grouping: results, by: \.modelName)

        return VStack(alignment: .leading, spacing: 10) {
            // 表头
            HStack {
                Text("模型")
                    .font(.caption.weight(.semibold))
                    .frame(width: 90, alignment: .leading)
                Text("速度")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                Text("首字")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                Text("总耗时")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                Text("内存")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                Text("质量")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)

            Divider()

            // 计算各维度最优值
            let speedValues = models.map { m in avg((grouped[m] ?? []).map(\.metrics.decodeTokensPerSecond)) }
            let ttftValues = models.map { m in avg((grouped[m] ?? []).map(\.metrics.timeToFirstToken)) }
            let timeValues = models.map { m in avg((grouped[m] ?? []).map(\.metrics.totalTime)) }
            let memValues = models.map { m in avg((grouped[m] ?? []).map { Double($0.metrics.peakMemoryUsage) }) }
            let qualityValues = models.map { m -> Double in
                let scored = (grouped[m] ?? []).filter { $0.qualityScore.totalScore >= 0 }
                guard !scored.isEmpty else { return 0 }
                return Double(scored.map(\.qualityScore.totalScore).reduce(0, +)) / Double(scored.count)
            }

            let bestSpeed = speedValues.max() ?? 0
            let bestTTFT = ttftValues.min() ?? 0
            let bestTime = timeValues.min() ?? 0
            let bestMem = memValues.min() ?? 0
            let bestQuality = qualityValues.max() ?? 0

            // 每个模型一行
            ForEach(Array(models.enumerated()), id: \.offset) { idx, modelName in
                let speed = speedValues[idx]
                let ttft = ttftValues[idx]
                let time = timeValues[idx]
                let mem = memValues[idx]
                let quality = qualityValues[idx]

                HStack {
                    Text(modelName)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 90, alignment: .leading)
                    compareCell(
                        text: String(format: "%.1ft/s", speed),
                        isBest: speed == bestSpeed && models.count > 1
                    )
                    compareCell(
                        text: String(format: "%.0fms", ttft * 1000),
                        isBest: ttft == bestTTFT && models.count > 1
                    )
                    compareCell(
                        text: String(format: "%.1fs", time),
                        isBest: time == bestTime && models.count > 1
                    )
                    compareCell(
                        text: MemoryUtils.formatBytes(UInt64(mem)),
                        isBest: mem == bestMem && models.count > 1
                    )
                    compareCell(
                        text: quality > 0 ? String(format: "%.0f\(L10n.score)", quality) : "-",
                        isBest: quality == bestQuality && quality > 0 && models.count > 1
                    )
                }
            }

            // 图例
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("= 该维度最优")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private func compareCell(text: String, isBest: Bool) -> some View {
        Text(text)
            .font(.caption.monospacedDigit().weight(isBest ? .bold : .regular))
            .foregroundStyle(isBest ? .green : .primary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 逐项对比（每个用例横向比模型）

    private var perTestCaseComparison: some View {
        let models = modelNamesInResults
        let grouped = Dictionary(grouping: results, by: \.testCaseId)
        let selectedTests = testCases.filter { grouped[$0.id] != nil }

        return ForEach(selectedTests) { testCase in
            let caseResults = grouped[testCase.id] ?? []
            if caseResults.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(testCase.name)
                        .font(.subheadline.weight(.medium))
                    Text(testCase.category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    // 速度对比
                    let speeds = models.compactMap { m in caseResults.first(where: { $0.modelName == m }) }
                    let bestSpeed = speeds.max(by: { $0.metrics.decodeTokensPerSecond < $1.metrics.decodeTokensPerSecond })

                    ForEach(speeds) { r in
                        HStack(spacing: 6) {
                            Text(r.modelName)
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                                .lineLimit(1)

                            // 速度条
                            let maxSpeed = bestSpeed?.metrics.decodeTokensPerSecond ?? 1
                            let ratio = maxSpeed > 0 ? r.metrics.decodeTokensPerSecond / maxSpeed : 0
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(r.id == bestSpeed?.id ? Color.green : Color.blue.opacity(0.4))
                                    .frame(width: geo.size.width * ratio)
                            }
                            .frame(height: 14)

                            Text(String(format: "%.1ft/s", r.metrics.decodeTokensPerSecond))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(r.id == bestSpeed?.id ? .green : .secondary)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var modelNamesInResults: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for r in results {
            if seen.insert(r.modelName).inserted {
                ordered.append(r.modelName)
            }
        }
        return ordered
    }

    private func modelGroupHeader(modelName: String, results: [BenchmarkResult]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(modelName)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                let avgSpeed = results.map(\.metrics.decodeTokensPerSecond).reduce(0, +) / max(Double(results.count), 1)
                let avgTTFT = results.map(\.metrics.timeToFirstToken).reduce(0, +) / max(Double(results.count), 1)
                Text(String(format: "%@ %.1f t/s", L10n.avgSpeed, avgSpeed))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%@ %.0fms", L10n.avgTTFT, avgTTFT * 1000))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // 平均质量评分
                let scored = results.filter { $0.qualityScore.totalScore >= 0 }
                if !scored.isEmpty {
                    let avgScore = scored.map(\.qualityScore.totalScore).reduce(0, +) / scored.count
                    Text("\(L10n.qualityLabel) \(avgScore)\(L10n.score)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(avgScore >= 80 ? .green : avgScore >= 40 ? .orange : .red)
                }

                Text("\(results.count)\(L10n.cases)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func resultRow(_ result: BenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 用例名 + 质量评分
            HStack {
                Text(result.testCaseName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                qualityBadge(result.qualityScore)
            }

            // 性能指标
            HStack(spacing: 16) {
                miniMetric(label: L10n.ttft, value: String(format: "%.0fms", result.metrics.timeToFirstToken * 1000))
                miniMetric(label: L10n.speed, value: String(format: "%.1ft/s", result.metrics.decodeTokensPerSecond))
                miniMetric(label: L10n.totalTime, value: String(format: "%.1fs", result.metrics.totalTime))
                miniMetric(label: "Token", value: "\(result.metrics.totalGeneratedTokens)")
            }

            // Prompt 预览
            if let testCase = testCases.first(where: { $0.id == result.testCaseId }) {
                Text(testCase.prompt.prefix(80) + (testCase.prompt.count > 80 ? "..." : ""))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            // 查看详情（独立页面）
            NavigationLink {
                BenchmarkResultDetailView(
                    result: result,
                    prompt: testCases.first(where: { $0.id == result.testCaseId })?.prompt ?? ""
                )
            } label: {
                Text(L10n.viewReplyAndPrompt)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func qualityBadge(_ score: QualityScore) -> some View {
        if score.totalScore >= 0 {
            Text("\(score.totalScore)\(L10n.score) \(score.level.rawValue)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(score.level == .pass ? .green : score.level == .partial ? .orange : .red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((score.level == .pass ? Color.green : score.level == .partial ? Color.orange : Color.red).opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func avg(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
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

    // MARK: - 运行逻辑（按模型顺序，每个模型测完卸载）

    private func runBenchmark() async {
        isRunning = true
        results.removeAll()

        let selectedTests = testCases.filter { selectedTestCases.contains($0.id) }
        modelTotal = selectedModels.count
        let totalTasks = selectedTests.count * selectedModels.count
        var completedTasks = 0

        for (mIdx, modelId) in selectedModels.enumerated() {
            guard let provider = modelManager.providers.first(where: { $0.id == modelId }) else { continue }

            modelIndex = mIdx + 1
            currentModelName = provider.displayName
            currentTask = "正在加载模型..."

            // 加载模型
            if provider.state == .unloaded || provider.state != .ready {
                do {
                    try await provider.load()
                } catch {
                    // 加载失败，跳过该模型
                    currentTask = "加载失败: \(error.localizedDescription)"
                    completedTasks += selectedTests.count
                    progress = Double(completedTasks) / Double(totalTasks)
                    continue
                }
            }

            // 对该模型执行所有测试用例
            for testCase in selectedTests {
                currentTask = testCase.name

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
                    response = "[\(L10n.error): \(error.localizedDescription)]"
                }

                if let metrics = finalMetrics {
                    let score = QualityScorer.evaluate(response: response, rules: testCase.qualityRules)
                    let result = BenchmarkResult(
                        testCaseId: testCase.id,
                        testCaseName: testCase.name,
                        modelName: provider.displayName,
                        providerType: provider.providerType,
                        architectureType: provider.architectureType,
                        metrics: metrics,
                        response: response,
                        qualityScore: score
                    )
                    results.append(result)
                }

                completedTasks += 1
                progress = Double(completedTasks) / Double(totalTasks)
            }

            // 测完该模型后卸载，释放内存给下一个模型
            currentTask = "正在卸载模型..."
            provider.unload()
        }

        isRunning = false
        currentTask = "测评完成"
        currentModelName = ""
    }
}

// MARK: - 测评结果详情页

struct BenchmarkResultDetailView: View {
    let result: BenchmarkResult
    let prompt: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 模型 + 用例信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.modelName)
                        .font(.headline)
                    HStack {
                        Text(result.testCaseName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(result.providerType.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Divider()

                // 性能指标
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.performanceMetrics)
                        .font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        metricCard(label: L10n.ttft, value: String(format: "%.0f ms", result.metrics.timeToFirstToken * 1000))
                        metricCard(label: L10n.speed, value: String(format: "%.1f t/s", result.metrics.decodeTokensPerSecond))
                        metricCard(label: L10n.totalTime, value: String(format: "%.2f s", result.metrics.totalTime))
                        metricCard(label: L10n.genTokens, value: "\(result.metrics.totalGeneratedTokens)")
                        metricCard(label: L10n.peakMemory, value: MemoryUtils.formatBytes(result.metrics.peakMemoryUsage))
                        metricCard(label: L10n.inputLength, value: "\(result.metrics.inputTokenCount)\(L10n.chars)")
                    }
                }

                Divider()

                // 质量评分
                if result.qualityScore.totalScore >= 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.qualityScore)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(result.qualityScore.totalScore) \(L10n.score)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(result.qualityScore.level == .pass ? .green : result.qualityScore.level == .partial ? .orange : .red)
                            Text(result.qualityScore.level.rawValue)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(result.qualityScore.level == .pass ? Color.green : result.qualityScore.level == .partial ? Color.orange : Color.red)
                                .clipShape(Capsule())
                        }

                        // 逐条规则结果
                        ForEach(result.qualityScore.ruleResults) { rule in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: rule.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(rule.passed ? .green : .red)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.ruleName)
                                        .font(.caption.weight(.medium))
                                    Text(rule.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("×\(rule.weight)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Divider()

                // Prompt
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prompt")
                        .font(.subheadline.weight(.semibold))
                    Text(prompt)
                        .font(.callout)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .textSelection(.enabled)
                }

                Divider()

                // 模型回复
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.modelReply)
                        .font(.subheadline.weight(.semibold))
                    StructuredText(markdown: result.response, syntaxExtensions: [.math])
                        .textual.structuredTextStyle(.gitHub)
                        .textual.textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .navigationTitle(L10n.benchmarkDetail)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricCard(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    BenchmarkView()
        .environmentObject(ModelManager())
}

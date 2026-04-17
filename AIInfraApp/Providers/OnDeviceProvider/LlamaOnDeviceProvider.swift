//
//  LlamaOnDeviceProvider.swift
//  AIInfraApp
//
//  基于 LlamaEngine 的真实端侧推理 Provider
//  实现 AIModelProvider 协议，可直接注册到 ModelManager
//

import Foundation

// MARK: - LlamaOnDeviceProvider

/// 使用 llama.cpp (LlamaEngine) 进行真实本地推理的 Provider
/// localPath 为 nil 时表示模型未下载，chat() 会直接抛出错误提示用户先下载
final class LlamaOnDeviceProvider: AIModelProvider, @unchecked Sendable {

    // MARK: - AIModelProvider 协议属性

    let id: String
    let displayName: String
    let description: String
    let descriptionEN: String
    let providerType: AIModelProviderType = .onDevice
    let architectureType: ModelArchitectureType
    let modelInfo: ModelInfo

    private(set) var state: AIModelState

    // MARK: - 私有属性

    private let engine: LlamaEngine?   // nil 表示未下载
    private var cancelFlag = false

    // MARK: - 初始化

    /// - Parameters:
    ///   - model: 模型目录信息
    ///   - localPath: 已下载的本地路径；nil 表示尚未下载
    init(model: DownloadableModel, localPath: URL?) {
        self.id = model.id
        self.displayName = model.displayName
        self.description = model.description
        self.descriptionEN = model.descriptionEN
        self.architectureType = model.architectureType
        self.modelInfo = ModelInfo(
            family: model.family,
            parameterCount: model.parameterCount,
            quantization: model.quantization,
            fileSize: model.fileSizeBytes,
            contextLength: model.contextLength,
            supportedLanguages: model.supportedLanguages,
            summary: model.description
        )

        if let localPath {
            self.engine = LlamaEngine(
                modelPath: localPath.path,
                contextLength: UInt32(model.contextLength),
                gpuEnabled: true
            )
            self.state = .unloaded
        } else {
            self.engine = nil
            self.state = .error("模型未下载，请到「模型商店」下载后使用")
        }
    }

    // MARK: - AIModelProvider 协议方法

    /// 加载模型（在后台线程执行，避免阻塞主线程）
    func load() async throws {
        guard let engine else {
            throw LlamaEngineError.loadFailed("模型文件不存在，请先到「模型商店」下载")
        }
        guard !engine.isLoaded else {
            state = .ready
            return
        }

        state = .loading
        do {
            // llama_model_load_from_file 是阻塞调用，需要在非主线程执行
            try await Task.detached(priority: .userInitiated) {
                try engine.load()
            }.value
            state = .ready
            print("[LlamaOnDeviceProvider] 模型加载完成: \(displayName)")
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    /// 卸载模型，释放内存
    func unload() {
        engine?.unload()
        state = engine != nil ? .unloaded : .error("模型未下载，请到「模型商店」下载后使用")
        print("[LlamaOnDeviceProvider] 模型已卸载: \(displayName)")
    }

    /// 流式对话生成
    func chat(messages: [ChatMessage], config: GenerationConfig) -> AsyncThrowingStream<StreamToken, Error> {
        AsyncThrowingStream { continuation in
            guard let engine = self.engine else {
                continuation.finish(throwing: LlamaEngineError.loadFailed("模型文件不存在，请先到「模型商店」下载"))
                return
            }

            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else {
                    continuation.finish(throwing: LlamaEngineError.notLoaded)
                    return
                }

                self.cancelFlag = false

                // 如果模型还未加载，先加载
                if !engine.isLoaded {
                    do {
                        try engine.load()
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }

                await MainActor.run { self.state = .generating }

                let startTime = CFAbsoluteTimeGetCurrent()
                var tokenCount = 0
                var decodeStartTime = CFAbsoluteTimeGetCurrent()

                // 将 ChatMessage 转换为 LlamaEngine 需要的格式
                let llamaMessages = messages.map { (role: $0.role.rawValue, content: $0.content) }

                do {
                    try engine.generate(
                        messages: llamaMessages,
                        temperature: config.temperature,
                        topK: Int32(config.topK),
                        topP: config.topP,
                        maxTokens: config.maxTokens,
                        repeatPenalty: config.repeatPenalty,
                        onToken: { text in
                            if tokenCount == 0 {
                                decodeStartTime = CFAbsoluteTimeGetCurrent()
                            }
                            tokenCount += 1
                            continuation.yield(StreamToken(text: text, isFinished: false, metrics: nil))
                        },
                        isCancelled: { self.cancelFlag }
                    )

                    let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                    let decodeTime = CFAbsoluteTimeGetCurrent() - decodeStartTime
                    let prefillTime = decodeStartTime - startTime

                    let metrics = GenerationMetrics(
                        modelName: self.displayName,
                        prefillTime: prefillTime,
                        prefillTokensPerSecond: 0,
                        decodeTime: decodeTime,
                        decodeTokensPerSecond: Double(tokenCount) / max(decodeTime, 0.001),
                        timeToFirstToken: prefillTime,
                        totalGeneratedTokens: tokenCount,
                        totalTime: totalTime,
                        peakMemoryUsage: MemoryUtils.currentMemoryUsage,
                        inputTokenCount: messages.last?.content.count ?? 0
                    )

                    continuation.yield(StreamToken(text: "", isFinished: true, metrics: metrics))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }

                await MainActor.run { self.state = .ready }
            }
        }
    }

    /// 取消当前生成任务
    func cancelGeneration() {
        cancelFlag = true
        state = .ready
        print("[LlamaOnDeviceProvider] 取消生成: \(displayName)")
    }
}

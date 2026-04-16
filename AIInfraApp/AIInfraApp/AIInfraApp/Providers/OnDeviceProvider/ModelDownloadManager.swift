import Foundation
import Combine

// MARK: - 模型下载管理器

/// 在 App 内直接下载 GGUF 模型文件到手机
///
/// 核心设计：
/// - 支持后台下载（用户可以切到其他页面）
/// - 支持暂停/恢复
/// - 下载进度实时回调
/// - 自动存储到 App 的 Documents/Models 目录
/// - 支持检查已下载的模型
@MainActor
final class ModelDownloadManager: NSObject, ObservableObject {

    // MARK: - Published 状态

    /// 当前所有下载任务的状态
    @Published var downloadStates: [String: DownloadState] = [:]

    /// 已下载的模型列表
    @Published var downloadedModels: [DownloadedModelInfo] = []

    // MARK: - 单例

    static let shared = ModelDownloadManager()

    // MARK: - Private

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600 // 1 小时超时
        config.allowsCellularAccess = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var progressHandlers: [String: (Double) -> Void] = [:]
    private var completionHandlers: [String: (Result<URL, Error>) -> Void] = [:]

    // MARK: - 模型存储路径

    /// 模型文件存储目录: Documents/Models/
    nonisolated static var modelsDirectory: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = documentsDir.appendingPathComponent("Models", isDirectory: true)

        if !FileManager.default.fileExists(atPath: modelsDir.path) {
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        return modelsDir
    }

    /// 获取模型文件的本地路径
    nonisolated static func localPath(for model: DownloadableModel) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }

    // MARK: - Init

    private override init() {
        super.init()
        refreshDownloadedModels()
    }

    // MARK: - 公共方法

    /// 检查模型是否已下载
    func isModelDownloaded(_ model: DownloadableModel) -> Bool {
        let path = Self.localPath(for: model)
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// 获取已下载模型的本地路径，如果未下载返回 nil
    func localPathIfDownloaded(_ model: DownloadableModel) -> URL? {
        let path = Self.localPath(for: model)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    /// 开始下载模型
    func downloadModel(_ model: DownloadableModel) {
        guard downloadStates[model.id] == nil || downloadStates[model.id] == .failed("") else {
            return // 已在下载或已完成
        }

        guard let url = URL(string: model.effectiveDownloadURL) else {
            downloadStates[model.id] = .failed("无效的下载地址")
            return
        }

        downloadStates[model.id] = .downloading(progress: 0)

        let task = session.downloadTask(with: url)
        task.taskDescription = model.id // 用 taskDescription 关联 model id
        activeTasks[model.id] = task
        task.resume()
    }

    /// 暂停下载
    func pauseDownload(_ modelId: String) {
        activeTasks[modelId]?.cancel(byProducingResumeData: { [weak self] data in
            DispatchQueue.main.async {
                if let data {
                    self?.downloadStates[modelId] = .paused(resumeData: data)
                }
            }
        })
        activeTasks.removeValue(forKey: modelId)
    }

    /// 恢复下载
    func resumeDownload(_ modelId: String) {
        guard case .paused(let resumeData) = downloadStates[modelId] else { return }

        downloadStates[modelId] = .downloading(progress: 0)

        let task = session.downloadTask(withResumeData: resumeData)
        task.taskDescription = modelId
        activeTasks[modelId] = task
        task.resume()
    }

    /// 取消下载
    func cancelDownload(_ modelId: String) {
        activeTasks[modelId]?.cancel()
        activeTasks.removeValue(forKey: modelId)
        downloadStates.removeValue(forKey: modelId)
    }

    /// 删除已下载的模型
    func deleteModel(_ model: DownloadableModel) {
        let path = Self.localPath(for: model)
        try? FileManager.default.removeItem(at: path)
        downloadStates.removeValue(forKey: model.id)
        refreshDownloadedModels()
    }

    /// 刷新已下载的模型列表
    func refreshDownloadedModels() {
        var downloaded: [DownloadedModelInfo] = []

        for model in GGUFModelCatalog.allModels {
            let path = Self.localPath(for: model)
            if FileManager.default.fileExists(atPath: path.path) {
                let attrs = try? FileManager.default.attributesOfItem(atPath: path.path)
                let fileSize = attrs?[.size] as? Int64 ?? 0

                downloaded.append(DownloadedModelInfo(
                    catalogModel: model,
                    localPath: path,
                    actualFileSize: fileSize,
                    downloadDate: attrs?[.modificationDate] as? Date ?? Date()
                ))

                // 更新状态为已完成
                downloadStates[model.id] = .completed
            }
        }

        downloadedModels = downloaded
    }

    /// 获取所有模型占用的总存储空间
    var totalStorageUsed: Int64 {
        downloadedModels.reduce(0) { $0 + $1.actualFileSize }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let modelId = downloadTask.taskDescription else { return }

        // 找到对应的模型信息
        guard let model = GGUFModelCatalog.allModels.first(where: { $0.id == modelId }) else { return }

        let destinationURL = Self.localPath(for: model)

        do {
            // 如果已存在旧文件，先删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            // 移动下载的临时文件到目标位置
            try FileManager.default.moveItem(at: location, to: destinationURL)

            DispatchQueue.main.async { [weak self] in
                self?.downloadStates[modelId] = .completed
                self?.activeTasks.removeValue(forKey: modelId)
                self?.refreshDownloadedModels()
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.downloadStates[modelId] = .failed("保存失败: \(error.localizedDescription)")
                self?.activeTasks.removeValue(forKey: modelId)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let modelId = downloadTask.taskDescription else { return }

        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            // 如果服务器没返回 Content-Length，用已知的文件大小估算
            if let model = GGUFModelCatalog.allModels.first(where: { $0.id == modelId }) {
                progress = Double(totalBytesWritten) / Double(model.fileSizeBytes)
            } else {
                progress = 0
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.downloadStates[modelId] = .downloading(progress: min(progress, 1.0))
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let modelId = task.taskDescription, let error else { return }

        // 如果是用户取消，不算错误
        if (error as NSError).code == NSURLErrorCancelled { return }

        DispatchQueue.main.async { [weak self] in
            self?.downloadStates[modelId] = .failed(error.localizedDescription)
            self?.activeTasks.removeValue(forKey: modelId)
        }
    }
}

// MARK: - 下载状态

/// 模型下载状态
enum DownloadState: Equatable {
    case downloading(progress: Double)
    case paused(resumeData: Data)
    case completed
    case failed(String)

    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.downloading(let a), .downloading(let b)):
            return a == b
        case (.completed, .completed):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.paused, .paused):
            return true
        default:
            return false
        }
    }
}

/// 已下载的模型信息
struct DownloadedModelInfo: Identifiable {
    var id: String { catalogModel.id }
    let catalogModel: DownloadableModel
    let localPath: URL
    let actualFileSize: Int64
    let downloadDate: Date
}

import Foundation

// MARK: - 图片数据集管理器

/// 管理 CIFAR-10 测试图片的下载和本地存储
/// 图片不打包在工程中，运行时按需下载到 Documents/ImageDatasets/
@MainActor
final class ImageDatasetManager: ObservableObject {

    // MARK: - Published 状态

    /// 下载进度 (0.0 ~ 1.0)
    @Published var downloadProgress: Double = 0

    /// 是否正在下载
    @Published var isDownloading = false

    /// 已下载的图片数量
    @Published var downloadedCount: Int = 0

    /// 下载错误信息
    @Published var errorMessage: String?

    // MARK: - 单例

    static let shared = ImageDatasetManager()

    // MARK: - 常量

    /// CIFAR-10 的 10 个类别
    static let categories = [
        "airplane", "automobile", "bird", "cat", "deer",
        "dog", "frog", "horse", "ship", "truck"
    ]

    /// 每个类别取前 50 张
    static let imagesPerCategory = 50

    /// 总图片数
    static let totalImages = categories.count * imagesPerCategory  // 500

    /// GitHub Raw URL 基地址
    private static let baseURL = "https://raw.githubusercontent.com/YoongiKim/CIFAR-10-images/master/test"

    // MARK: - 存储路径

    /// 图片数据集根目录: Documents/ImageDatasets/cifar10/
    nonisolated static var datasetDirectory: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsDir
            .appendingPathComponent("ImageDatasets", isDirectory: true)
            .appendingPathComponent("cifar10", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 获取指定类别图片的本地路径
    /// - Parameters:
    ///   - category: 类别名 (如 "airplane")
    ///   - index: 图片编号 (0-49)
    nonisolated static func localImagePath(category: String, index: Int) -> URL {
        let categoryDir = datasetDirectory.appendingPathComponent(category, isDirectory: true)
        if !FileManager.default.fileExists(atPath: categoryDir.path) {
            try? FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
        }
        return categoryDir.appendingPathComponent(String(format: "%04d.jpg", index))
    }

    /// 获取指定图片的下载 URL
    nonisolated static func remoteImageURL(category: String, index: Int) -> URL? {
        URL(string: "\(baseURL)/\(category)/\(String(format: "%04d.jpg", index))")
    }

    // MARK: - Init

    private init() {
        refreshDownloadedCount()
    }

    // MARK: - 公共方法

    /// 刷新已下载图片计数
    func refreshDownloadedCount() {
        var count = 0
        for category in Self.categories {
            for i in 0..<Self.imagesPerCategory {
                let path = Self.localImagePath(category: category, index: i)
                if FileManager.default.fileExists(atPath: path.path) {
                    count += 1
                }
            }
        }
        downloadedCount = count
    }

    /// 是否已完成全部下载
    var isFullyDownloaded: Bool {
        downloadedCount >= Self.totalImages
    }

    /// 加载指定图片的 Data
    /// - Returns: JPEG 图片数据，未下载则返回 nil
    nonisolated func loadImageData(category: String, index: Int) -> Data? {
        let path = Self.localImagePath(category: category, index: index)
        return try? Data(contentsOf: path)
    }

    /// 批量下载所有测试图片
    func downloadAllImages() async {
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        errorMessage = nil

        var completed = 0
        var failed = 0
        let total = Self.totalImages

        for category in Self.categories {
            for i in 0..<Self.imagesPerCategory {
                let localPath = Self.localImagePath(category: category, index: i)

                // 已存在则跳过
                if FileManager.default.fileExists(atPath: localPath.path) {
                    completed += 1
                    downloadProgress = Double(completed) / Double(total)
                    continue
                }

                guard let url = Self.remoteImageURL(category: category, index: i) else {
                    failed += 1
                    completed += 1
                    continue
                }

                // 下载
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        failed += 1
                        completed += 1
                        downloadProgress = Double(completed) / Double(total)
                        continue
                    }

                    try data.write(to: localPath)
                } catch {
                    failed += 1
                }

                completed += 1
                downloadProgress = Double(completed) / Double(total)
            }
        }

        refreshDownloadedCount()
        isDownloading = false

        if failed > 0 {
            errorMessage = "下载完成，\(failed) 张失败"
        }
    }

    /// 删除所有已下载的测试图片
    func deleteAllImages() {
        try? FileManager.default.removeItem(at: Self.datasetDirectory)
        // 重新创建空目录
        try? FileManager.default.createDirectory(at: Self.datasetDirectory, withIntermediateDirectories: true)
        refreshDownloadedCount()
    }

    /// 已下载图片占用的存储空间
    var storageUsed: Int64 {
        var total: Int64 = 0
        let fm = FileManager.default
        for category in Self.categories {
            for i in 0..<Self.imagesPerCategory {
                let path = Self.localImagePath(category: category, index: i)
                if let attrs = try? fm.attributesOfItem(atPath: path.path),
                   let size = attrs[.size] as? Int64 {
                    total += size
                }
            }
        }
        return total
    }
}

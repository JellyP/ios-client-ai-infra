import Foundation

// MARK: - 应用设置

/// 应用配置存储（UserDefaults）
struct APIKeyStore {

    private static let defaults = UserDefaults.standard

    /// 模型下载镜像源
    static var downloadMirror: DownloadMirror {
        get {
            let raw = defaults.string(forKey: "download_mirror") ?? DownloadMirror.hfMirror.rawValue
            return DownloadMirror(rawValue: raw) ?? .hfMirror
        }
        set { defaults.set(newValue.rawValue, forKey: "download_mirror") }
    }
}

// MARK: - 下载镜像源

/// 模型下载镜像源选择
enum DownloadMirror: String, CaseIterable, Codable {
    /// HuggingFace 国内镜像（hf-mirror.com），路径兼容，中国大陆可用
    case hfMirror = "hf-mirror"
    /// HuggingFace 官方（huggingface.co），需要科学上网
    case huggingface = "huggingface"

    var displayName: String {
        switch self {
        case .hfMirror: return "国内镜像 (hf-mirror.com)"
        case .huggingface: return "HuggingFace 官方"
        }
    }

    var description: String {
        switch self {
        case .hfMirror: return "中国大陆可直连，推荐"
        case .huggingface: return "需要科学上网"
        }
    }
}

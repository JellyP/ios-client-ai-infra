import Foundation

// MARK: - API Key 配置管理

/// 管理远程模型的 API Key 配置
/// 存储在 UserDefaults 中（生产环境应使用 Keychain）
struct APIKeyStore {

    private static let defaults = UserDefaults.standard

    /// 获取 OpenAI API Key
    static var openAIKey: String {
        get { defaults.string(forKey: "api_key_openai") ?? "" }
        set { defaults.set(newValue, forKey: "api_key_openai") }
    }

    /// 获取 DeepSeek API Key
    static var deepSeekKey: String {
        get { defaults.string(forKey: "api_key_deepseek") ?? "" }
        set { defaults.set(newValue, forKey: "api_key_deepseek") }
    }

    /// 获取自定义 API 的 Base URL
    static var customBaseURL: String {
        get { defaults.string(forKey: "api_custom_base_url") ?? "" }
        set { defaults.set(newValue, forKey: "api_custom_base_url") }
    }

    /// 获取自定义 API Key
    static var customAPIKey: String {
        get { defaults.string(forKey: "api_key_custom") ?? "" }
        set { defaults.set(newValue, forKey: "api_key_custom") }
    }

    /// 获取自定义模型 ID
    static var customModelId: String {
        get { defaults.string(forKey: "api_custom_model_id") ?? "" }
        set { defaults.set(newValue, forKey: "api_custom_model_id") }
    }

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

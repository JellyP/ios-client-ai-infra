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
}

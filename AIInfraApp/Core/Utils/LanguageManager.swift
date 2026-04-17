import Foundation

// MARK: - Language Manager

/// App-level language manager. Allows switching language within the app
/// independent of system language settings. Default: Chinese.
@MainActor
final class LanguageManager: ObservableObject {

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }

    static let shared = LanguageManager()

    private init() {
        let raw = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.chinese.rawValue
        self.currentLanguage = AppLanguage(rawValue: raw) ?? .chinese
    }
}

/// Supported app languages
enum AppLanguage: String, CaseIterable, Codable {
    case chinese = "zh"
    case english = "en"

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

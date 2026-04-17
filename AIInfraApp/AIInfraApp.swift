import SwiftUI

/// App 入口
@main
struct AIInfraApp: App {
    @StateObject private var modelManager = ModelManager()
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(modelManager)
                .environmentObject(languageManager)
        }
    }
}

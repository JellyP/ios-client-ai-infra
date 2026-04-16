import SwiftUI

/// App 入口
@main
struct AIInfraApp: App {
    @StateObject private var modelManager = ModelManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(modelManager)
        }
    }
}

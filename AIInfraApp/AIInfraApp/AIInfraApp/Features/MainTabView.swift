import SwiftUI

/// 主 Tab 视图 —— App 的导航入口
struct MainTabView: View {
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label(L10n.tabChat, systemImage: "message.fill")
                }

            BenchmarkView()
                .tabItem {
                    Label(L10n.tabBenchmark, systemImage: "chart.bar.fill")
                }

            ModelListView()
                .tabItem {
                    Label(L10n.tabModels, systemImage: "cpu.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(ModelManager())
        .environmentObject(LanguageManager.shared)
}

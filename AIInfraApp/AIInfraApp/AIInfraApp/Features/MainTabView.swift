import SwiftUI

/// 主 Tab 视图 —— App 的导航入口
struct MainTabView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label("对话", systemImage: "message.fill")
                }

            BenchmarkView()
                .tabItem {
                    Label("测评", systemImage: "chart.bar.fill")
                }

            ModelListView()
                .tabItem {
                    Label("模型", systemImage: "cpu.fill")
                }

            LearnView()
                .tabItem {
                    Label("学习", systemImage: "book.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(ModelManager())
}

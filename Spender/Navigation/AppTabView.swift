import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            TransactionListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }

            CategoryBreakdownView()
                .tabItem {
                    Label("Categories", systemImage: "chart.pie.fill")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "lightbulb.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

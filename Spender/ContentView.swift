import SwiftUI
import SwiftData

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case transactions = "Transactions"
    case importStatements = "Import"
    case analysis = "Analysis"
    case chat = "Chat"
    case devTools = "Developer Tools"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "house.fill"
        case .transactions: "list.bullet"
        case .importStatements: "doc.badge.plus"
        case .analysis: "chart.bar.fill"
        case .chat: "bubble.left.and.bubble.right.fill"
        case .devTools: "wrench.and.screwdriver.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .analysis
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            switch selectedItem {
            case .dashboard:
                DashboardView()
            case .transactions:
                TransactionListView()
            case .importStatements:
                ImportView()
            case .analysis:
                AnalysisView()
            case .chat:
                ChatView()
            case .devTools:
                DevToolsView()
            case nil:
                Text("Select an item from the sidebar")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

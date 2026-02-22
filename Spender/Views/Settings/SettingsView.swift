import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            CardManagementView()
                .tabItem {
                    Label("Cards", systemImage: "creditcard.fill")
                }

            CategoryManagementView()
                .tabItem {
                    Label("Categories", systemImage: "tag.fill")
                }

            APIKeySettingsView()
                .tabItem {
                    Label("API Key", systemImage: "key.fill")
                }
        }
        .frame(width: 550, height: 450)
    }
}

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var importSessions: [ImportSession]
    @Query private var cacheEntries: [ClassificationCache]
    @Query private var categories: [SpendingCategory]
    @Query private var cards: [Card]
    @Query private var chatMessages: [ChatMessage]
    @State private var showDeleteConfirmation = false
    @State private var deleteAction: (() -> Void)?
    @State private var deleteMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Developer Tools")
                    .font(.title2.bold())

                GroupBox("Database Statistics") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Transactions", value: "\(transactions.count)")
                        LabeledContent("Import Sessions", value: "\(importSessions.count)")
                        LabeledContent("Classification Cache", value: "\(cacheEntries.count)")
                        LabeledContent("Categories", value: "\(categories.count)")
                        LabeledContent("Cards", value: "\(cards.count)")
                        LabeledContent("Chat Messages", value: "\(chatMessages.count)")
                    }
                    .padding(4)
                }

                GroupBox("Delete Data") {
                    VStack(alignment: .leading, spacing: 10) {
                        deleteButton("Delete All Transactions (\(transactions.count))", disabled: transactions.isEmpty) {
                            for txn in transactions { modelContext.delete(txn) }
                            for session in importSessions { modelContext.delete(session) }
                            try? modelContext.save()
                        }

                        deleteButton("Delete All Import Sessions (\(importSessions.count))", disabled: importSessions.isEmpty) {
                            for session in importSessions { modelContext.delete(session) }
                            try? modelContext.save()
                        }

                        deleteButton("Clear Classification Cache (\(cacheEntries.count))", disabled: cacheEntries.isEmpty) {
                            for entry in cacheEntries { modelContext.delete(entry) }
                            try? modelContext.save()
                        }

                        deleteButton("Delete All Chat History (\(chatMessages.count))", disabled: chatMessages.isEmpty) {
                            for msg in chatMessages { modelContext.delete(msg) }
                            try? modelContext.save()
                        }

                        deleteButton("Delete All Cards (\(cards.count))", disabled: cards.isEmpty) {
                            for card in cards { modelContext.delete(card) }
                            try? modelContext.save()
                        }

                        deleteButton("Reset Categories to Defaults", disabled: false) {
                            for cat in categories { modelContext.delete(cat) }
                            try? modelContext.save()
                            // Re-seed defaults
                            for (index, def) in SpendingCategory.defaults.enumerated() {
                                let cat = SpendingCategory(name: def.name, iconName: def.icon, colorHex: def.color, sortOrder: index)
                                modelContext.insert(cat)
                            }
                            try? modelContext.save()
                        }

                        Divider()

                        deleteButton("NUKE: Delete Everything", disabled: false) {
                            for txn in transactions { modelContext.delete(txn) }
                            for session in importSessions { modelContext.delete(session) }
                            for entry in cacheEntries { modelContext.delete(entry) }
                            for msg in chatMessages { modelContext.delete(msg) }
                            for card in cards { modelContext.delete(card) }
                            for cat in categories { modelContext.delete(cat) }
                            try? modelContext.save()
                        }
                    }
                    .padding(4)
                }

                GroupBox("Storage") {
                    VStack(alignment: .leading, spacing: 6) {
                        let dbPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("default.store").path ?? "unknown"
                        LabeledContent("DB Path") {
                            Text(dbPath)
                                .font(.caption2)
                                .textSelection(.enabled)
                                .lineLimit(1)
                        }

                        Button("Open DB Folder in Finder") {
                            if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        Button("Clear UserDefaults (API key etc.)") {
                            if let bundleId = Bundle.main.bundleIdentifier {
                                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                            }
                        }
                    }
                    .padding(4)
                }
            }
            .padding()
        }
        .alert("Confirm Delete", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { deleteAction = nil }
            Button("Delete", role: .destructive) {
                deleteAction?()
                deleteAction = nil
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private func deleteButton(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, role: .destructive) {
            deleteMessage = "Are you sure? This cannot be undone."
            deleteAction = action
            showDeleteConfirmation = true
        }
        .disabled(disabled)
    }
}

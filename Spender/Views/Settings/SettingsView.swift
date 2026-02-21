import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @Query private var settings: [UserSettings]
    @State private var showConnectAccount = false
    @State private var showDeleteConfirmation = false

    private var userSettings: UserSettings? {
        settings.first
    }

    var body: some View {
        NavigationStack {
            List {
                // Connected Accounts
                Section("Connected Accounts") {
                    ForEach(accounts) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.institutionName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(account.accountName) (\(account.mask))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if account.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Button {
                        showConnectAccount = true
                    } label: {
                        Label("Connect Account", systemImage: "plus.circle")
                    }
                }

                // Sync
                Section("Sync") {
                    if let lastSync = accounts.compactMap(\.lastSyncedAt).max() {
                        LabeledContent("Last Sync") {
                            Text(lastSync, format: .relative(presentation: .named))
                        }
                    }

                    Button {
                        // Sync will be connected in Phase 2
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                // Data Management
                Section("Data Management") {
                    if let settings = userSettings {
                        Picker("Retention Period", selection: Binding(
                            get: { settings.dataRetentionMonths },
                            set: { newValue in
                                settings.dataRetentionMonths = newValue
                                try? modelContext.save()
                            }
                        )) {
                            Text("6 months").tag(6)
                            Text("12 months").tag(12)
                            Text("24 months").tag(24)
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showConnectAccount) {
                AccountConnectionView()
            }
            .confirmationDialog("Clear All Data?", isPresented: $showDeleteConfirmation) {
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all transactions and disconnect all accounts. This cannot be undone.")
            }
        }
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Account.self)
            try modelContext.delete(model: SpendingSummary.self)
            try modelContext.delete(model: SyncCursor.self)
            try modelContext.save()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
}

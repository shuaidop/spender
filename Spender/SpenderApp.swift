import SwiftUI
import SwiftData

@main
struct SpenderApp: App {
    let modelContainer: ModelContainer
    @StateObject private var container = DIContainer()

    init() {
        do {
            let schema = Schema([
                Account.self,
                Transaction.self,
                Category.self,
                SpendingSummary.self,
                SyncCursor.self,
                UserSettings.self,
            ])
            let config = ModelConfiguration(
                "SpenderStore",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environmentObject(container)
                .onAppear {
                    seedDataIfNeeded()
                }
        }
        .modelContainer(modelContainer)
    }

    private func seedDataIfNeeded() {
        let context = modelContainer.mainContext
        do {
            try Category.seedCategories(in: context)

            // Ensure UserSettings exists
            let settingsDescriptor = FetchDescriptor<UserSettings>()
            if try context.fetchCount(settingsDescriptor) == 0 {
                context.insert(UserSettings())
                try context.save()
            }
        } catch {
            print("Failed to seed data: \(error)")
        }
    }
}

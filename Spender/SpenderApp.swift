import SwiftUI
import SwiftData

@main
struct SpenderApp: App {
    let sharedModelContainer: ModelContainer

    init() {
        do {
            sharedModelContainer = try ModelContainer(for:
                Transaction.self,
                Card.self,
                SpendingCategory.self,
                ClassificationCache.self,
                ImportSession.self,
                ChatMessage.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Seed default categories and add any new ones from updated defaults
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<SpendingCategory>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map(\.name))

        if existing.isEmpty {
            // Fresh install: seed all defaults
            for (index, cat) in SpendingCategory.defaults.enumerated() {
                let category = SpendingCategory(
                    name: cat.name,
                    iconName: cat.icon,
                    colorHex: cat.color,
                    sortOrder: index
                )
                context.insert(category)
            }
        } else {
            // Existing install: add any new categories that don't exist yet
            for (index, cat) in SpendingCategory.defaults.enumerated() {
                if !existingNames.contains(cat.name) {
                    let category = SpendingCategory(
                        name: cat.name,
                        iconName: cat.icon,
                        colorHex: cat.color,
                        sortOrder: index
                    )
                    context.insert(category)
                }
            }
        }
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
    }
}

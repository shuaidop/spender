import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemIconName: String
    var colorHex: String
    var isSystem: Bool
    var sortOrder: Int

    init(
        name: String,
        systemIconName: String,
        colorHex: String,
        isSystem: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.systemIconName = systemIconName
        self.colorHex = colorHex
        self.isSystem = isSystem
        self.sortOrder = sortOrder
    }

    static let defaults: [(name: String, icon: String, color: String)] = [
        ("Groceries", "cart.fill", "#4CAF50"),
        ("Dining", "fork.knife", "#FF9800"),
        ("Transportation", "car.fill", "#2196F3"),
        ("Subscriptions", "repeat", "#9C27B0"),
        ("Shopping", "bag.fill", "#E91E63"),
        ("Entertainment", "film", "#00BCD4"),
        ("Health", "heart.fill", "#F44336"),
        ("Travel", "airplane", "#3F51B5"),
        ("Bills & Utilities", "bolt.fill", "#FFC107"),
        ("Gas", "fuelpump.fill", "#795548"),
        ("Personal Care", "scissors", "#607D8B"),
        ("Education", "book.fill", "#8BC34A"),
        ("Gifts & Donations", "gift.fill", "#FF5722"),
        ("Other", "ellipsis.circle", "#9E9E9E"),
    ]

    static func seedCategories(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Category>()
        let existing = try context.fetchCount(descriptor)
        guard existing == 0 else { return }

        for (index, item) in defaults.enumerated() {
            let category = Category(
                name: item.name,
                systemIconName: item.icon,
                colorHex: item.color,
                sortOrder: index
            )
            context.insert(category)
        }
        try context.save()
    }
}

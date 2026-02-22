import Foundation
import SwiftData

@Model
final class SpendingCategory: Hashable {
    static func == (lhs: SpendingCategory, rhs: SpendingCategory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var id: UUID

    @Attribute(.unique)
    var name: String

    var iconName: String
    var colorHex: String
    var isDefault: Bool
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]

    init(
        name: String,
        iconName: String,
        colorHex: String,
        isDefault: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.transactions = []
    }

    static let defaults: [(name: String, icon: String, color: String)] = [
        // Food & Drink
        ("Dining Out", "fork.knife", "#FF6B6B"),
        ("Food Delivery", "bag.fill", "#FF8A80"),
        ("Coffee & Tea", "cup.and.saucer.fill", "#A1887F"),
        ("Fast Casual", "takeoutbag.and.cup.and.straw.fill", "#FFB74D"),
        ("Groceries", "cart.fill", "#4ECDC4"),
        ("Alcohol", "wineglass.fill", "#8E24AA"),
        // Transportation
        ("Rideshare", "car.fill", "#45B7D1"),
        ("Public Transit", "bus.fill", "#5C6BC0"),
        ("Parking", "parkingsign", "#78909C"),
        ("Gas", "fuelpump.fill", "#96CEB4"),
        ("Car Maintenance", "wrench.and.screwdriver.fill", "#607D8B"),
        // Travel
        ("Flights", "airplane", "#FFEAA7"),
        ("Hotels", "building.2.fill", "#FDD835"),
        ("Activities & Tours", "ticket.fill", "#26A69A"),
        // Shopping
        ("Online Shopping", "shippingbox.fill", "#98D8C8"),
        ("Luxury", "sparkle", "#CE93D8"),
        ("In Store Shopping", "tshirt.fill", "#F48FB1"),
        ("Electronics", "desktopcomputer", "#4DD0E1"),
        ("Home & Household", "house.fill", "#A8E6CF"),
        // Subscriptions & Software
        ("Software", "laptopcomputer", "#64B5F6"),
        ("Streaming", "play.tv.fill", "#7E57C2"),
        ("App Subscriptions", "app.badge.fill", "#F7DC6F"),
        // Personal
        ("Salon & Spa", "sparkles", "#FFD1DC"),
        ("Beauty & Skincare", "paintbrush.fill", "#F8BBD0"),
        ("Healthcare", "heart.fill", "#FF6F61"),
        ("Fitness", "figure.run", "#66BB6A"),
        // Housing & Bills
        ("Rent", "building.fill", "#90A4AE"),
        ("Utilities", "bolt.fill", "#87CEEB"),
        ("Insurance", "shield.fill", "#B8B8D1"),
        // Other
        ("Entertainment", "film.fill", "#DDA0DD"),
        ("Gifts & Donations", "gift.fill", "#C9B1FF"),
        ("Education", "book.fill", "#FFB347"),
        ("Smoke & Tobacco", "smoke.fill", "#8B7355"),
        ("Vending Machines", "dollarsign.square", "#BDBDBD"),
        ("Fees & Interest", "exclamationmark.triangle.fill", "#FF4757"),
        ("Income & Credits", "arrow.down.circle.fill", "#2ED573"),
        ("Uncategorized", "questionmark.circle.fill", "#95A5A6"),
    ]
}

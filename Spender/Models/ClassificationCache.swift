import Foundation
import SwiftData

@Model
final class ClassificationCache {
    var id: UUID

    @Attribute(.unique)
    var merchantPattern: String

    var cleanName: String
    var categoryName: String
    var lastUsed: Date

    init(merchantPattern: String, cleanName: String, categoryName: String) {
        self.id = UUID()
        self.merchantPattern = merchantPattern
        self.cleanName = cleanName
        self.categoryName = categoryName
        self.lastUsed = Date()
    }
}

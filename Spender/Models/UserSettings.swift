import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var deviceToken: String
    var defaultCurrency: String
    var dataRetentionMonths: Int
    var lastCleanupDate: Date?
    var enableNotifications: Bool
    var preferredChartPeriod: String

    init() {
        self.id = UUID()
        self.deviceToken = UUID().uuidString
        self.defaultCurrency = "USD"
        self.dataRetentionMonths = 12
        self.enableNotifications = false
        self.preferredChartPeriod = "week"
    }
}

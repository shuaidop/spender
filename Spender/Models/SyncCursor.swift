import Foundation
import SwiftData

@Model
final class SyncCursor {
    @Attribute(.unique) var plaidItemID: String
    var cursor: String?
    var lastSyncedAt: Date

    init(plaidItemID: String) {
        self.plaidItemID = plaidItemID
        self.lastSyncedAt = Date()
    }
}

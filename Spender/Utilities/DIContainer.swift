import Foundation
import SwiftData

/// Central dependency injection container.
/// Swap chart or chat implementations here without changing any views.
@MainActor
final class DIContainer: ObservableObject {
    let apiClient: APIClient
    let chartFactory: DefaultChartFactory

    init(baseURL: String = Constants.apiBaseURL) {
        self.apiClient = APIClient(baseURL: baseURL)
        self.chartFactory = DefaultChartFactory()
    }
}

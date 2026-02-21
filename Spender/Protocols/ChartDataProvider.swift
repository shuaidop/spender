import Foundation

/// Provides chart data from the local store.
/// ViewModels conform to this to feed data into chart views.
@MainActor
protocol ChartDataProvider: Observable {
    var weeklyData: [DailySpend] { get }
    var monthlyData: [MonthlySpend] { get }
    var categoryData: [CategorySpend] { get }
    var trendData: [WeeklyTotal] { get }
    func refresh() async
}

import SwiftUI

/// Factory that creates chart views.
/// Swap the entire chart rendering layer by providing a different factory implementation.
///
/// Usage in views:
/// ```
/// struct DashboardView<Factory: ChartFactory>: View {
///     let chartFactory: Factory
///     ...
///     chartFactory.makeWeeklyChart(data: viewModel.weeklyData)
/// }
/// ```
protocol ChartFactory {
    associatedtype Weekly: WeeklyChartRenderable
    associatedtype Monthly: MonthlyChartRenderable
    associatedtype CategoryChart: CategoryChartRenderable
    associatedtype Trend: TrendChartRenderable

    func makeWeeklyChart(data: [DailySpend]) -> Weekly
    func makeMonthlyChart(data: [MonthlySpend]) -> Monthly
    func makeCategoryChart(data: [CategorySpend]) -> CategoryChart
    func makeTrendChart(data: [WeeklyTotal]) -> Trend
}

import SwiftUI

/// Default chart factory using Apple's Swift Charts framework.
/// To swap chart implementations, create a new factory conforming to ChartFactory.
struct DefaultChartFactory: ChartFactory {
    func makeWeeklyChart(data: [DailySpend]) -> SwiftChartsWeekly {
        SwiftChartsWeekly(data: data)
    }

    func makeMonthlyChart(data: [MonthlySpend]) -> SwiftChartsMonthly {
        SwiftChartsMonthly(data: data)
    }

    func makeCategoryChart(data: [CategorySpend]) -> SwiftChartsPie {
        SwiftChartsPie(data: data)
    }

    func makeTrendChart(data: [WeeklyTotal]) -> SwiftChartsTrend {
        SwiftChartsTrend(data: data)
    }
}

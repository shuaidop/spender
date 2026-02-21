import SwiftUI

/// Protocol for weekly spending bar chart.
/// Conform a new view to this protocol and register in ChartFactory to swap implementations.
protocol WeeklyChartRenderable: View {
    init(data: [DailySpend])
}

/// Protocol for monthly spending bar chart.
protocol MonthlyChartRenderable: View {
    init(data: [MonthlySpend])
}

/// Protocol for category breakdown pie/donut chart.
protocol CategoryChartRenderable: View {
    init(data: [CategorySpend])
}

/// Protocol for weekly trend line chart.
protocol TrendChartRenderable: View {
    init(data: [WeeklyTotal])
}

import SwiftUI
import Charts

struct SwiftChartsWeekly: WeeklyChartRenderable {
    let data: [DailySpend]

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Day", item.date, unit: .day),
                y: .value("Amount", item.amount)
            )
            .foregroundStyle(by: .value("Category", item.category))
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let amount = value.as(Decimal.self) {
                        Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                    }
                }
            }
        }
        .chartLegend(position: .bottom, spacing: 8)
        .frame(height: 250)
    }
}

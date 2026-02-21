import SwiftUI
import Charts

struct SwiftChartsMonthly: MonthlyChartRenderable {
    let data: [MonthlySpend]

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Month", item.month, unit: .month),
                y: .value("Amount", item.totalSpend)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [.blue.opacity(0.6), .blue],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(6)
            .annotation(position: .top) {
                Text(
                    item.totalSpend,
                    format: .currency(code: "USD").precision(.fractionLength(0))
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .frame(height: 250)
    }
}

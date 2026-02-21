import SwiftUI
import Charts

struct SwiftChartsTrend: TrendChartRenderable {
    let data: [WeeklyTotal]

    var body: some View {
        Chart(data) { item in
            LineMark(
                x: .value("Week", item.weekStart),
                y: .value("Spend", item.total)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.blue)

            AreaMark(
                x: .value("Week", item.weekStart),
                y: .value("Spend", item.total)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.blue.opacity(0.1))

            PointMark(
                x: .value("Week", item.weekStart),
                y: .value("Spend", item.total)
            )
            .foregroundStyle(.blue)
            .symbolSize(30)
        }
        .frame(height: 200)
    }
}

import SwiftUI
import Charts

struct SwiftChartsPie: CategoryChartRenderable {
    let data: [CategorySpend]

    var body: some View {
        Chart(data) { item in
            SectorMark(
                angle: .value("Amount", item.amount),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("Category", item.category))
            .cornerRadius(4)
        }
        .chartLegend(position: .bottom, columns: 2)
        .frame(height: 300)
    }
}

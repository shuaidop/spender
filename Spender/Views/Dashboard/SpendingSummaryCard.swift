import SwiftUI

struct SpendingSummaryCard: View {
    let totalSpend: Decimal
    let transactionCount: Int
    let periodLabel: String

    var body: some View {
        VStack(spacing: 8) {
            Text(periodLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(totalSpend, format: .currency(code: "USD"))
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text("\(transactionCount) transactions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

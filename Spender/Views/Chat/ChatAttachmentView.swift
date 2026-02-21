import SwiftUI

struct ChatAttachmentView: View {
    let attachment: ChatAttachment

    var body: some View {
        switch attachment {
        case .spendingChart(let chartType, let periodType):
            VStack(alignment: .leading, spacing: 4) {
                Label("\(chartType) - \(periodType)", systemImage: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // Chart rendering will be implemented when ChatService is connected
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(height: 150)
                    .overlay {
                        Text("Chart Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

        case .transactionList(let ids):
            VStack(alignment: .leading, spacing: 4) {
                Label("\(ids.count) transactions", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

        case .summaryCard(let text):
            Text(text)
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

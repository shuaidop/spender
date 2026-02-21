import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: iconForCategory(transaction.effectiveCategory))
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(colorForCategory(transaction.effectiveCategory), in: Circle())

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName ?? transaction.originalDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(transaction.effectiveCategory)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())

                    if transaction.isPending {
                        Text("Pending")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Amount
            Text(transaction.amount, format: .currency(code: transaction.isoCurrencyCode))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(transaction.amount < 0 ? .green : .primary)
        }
        .padding(.vertical, 2)
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Groceries": return "cart.fill"
        case "Dining": return "fork.knife"
        case "Transportation": return "car.fill"
        case "Subscriptions": return "repeat"
        case "Shopping": return "bag.fill"
        case "Entertainment": return "film"
        case "Health": return "heart.fill"
        case "Travel": return "airplane"
        case "Bills & Utilities": return "bolt.fill"
        case "Gas": return "fuelpump.fill"
        case "Personal Care": return "scissors"
        case "Education": return "book.fill"
        case "Gifts & Donations": return "gift.fill"
        default: return "ellipsis.circle"
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Groceries": return .green
        case "Dining": return .orange
        case "Transportation": return .blue
        case "Subscriptions": return .purple
        case "Shopping": return .pink
        case "Entertainment": return .cyan
        case "Health": return .red
        case "Travel": return .indigo
        case "Bills & Utilities": return .yellow
        case "Gas": return .brown
        case "Personal Care": return .gray
        case "Education": return Color(red: 0.54, green: 0.76, blue: 0.29)
        case "Gifts & Donations": return Color(red: 1.0, green: 0.34, blue: 0.13)
        default: return .secondary
        }
    }
}

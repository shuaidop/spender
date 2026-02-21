import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let category: String

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    private var transactions: [Transaction] {
        allTransactions.filter { $0.effectiveCategory == category }
    }

    var body: some View {
        List {
            ForEach(transactions) { transaction in
                TransactionRowView(transaction: transaction)
            }
        }
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if transactions.isEmpty {
                ContentUnavailableView("No Transactions", systemImage: "tray")
            }
        }
    }
}

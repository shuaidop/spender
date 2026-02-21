import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var searchText = ""
    @State private var selectedCategory: String?

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.rectangle",
                        title: "No Transactions",
                        message: "Transactions will appear here after syncing with your bank."
                    )
                } else {
                    List {
                        ForEach(groupedTransactions, id: \.key) { dateString, txns in
                            Section(header: Text(dateString)) {
                                ForEach(txns) { transaction in
                                    NavigationLink(value: transaction.id) {
                                        TransactionRowView(transaction: transaction)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .navigationDestination(for: UUID.self) { transactionID in
                TransactionDetailView(transactionID: transactionID)
            }
        }
    }

    private var filteredTransactions: [Transaction] {
        var result = transactions

        if !searchText.isEmpty {
            result = result.filter { txn in
                let name = txn.merchantName ?? txn.originalDescription
                return name.localizedCaseInsensitiveContains(searchText)
                    || txn.effectiveCategory.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.effectiveCategory == category }
        }

        return result
    }

    private var groupedTransactions: [(key: String, value: [Transaction])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let grouped = Dictionary(grouping: filteredTransactions) { txn in
            formatter.string(from: txn.date)
        }

        return grouped
            .sorted { first, second in
                guard let d1 = first.value.first?.date, let d2 = second.value.first?.date else {
                    return false
                }
                return d1 > d2
            }
    }
}

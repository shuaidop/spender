import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Card.bankName) private var cards: [Card]
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]

    @State private var searchText = ""
    @State private var selectedCard: Card?
    @State private var selectedCategory: SpendingCategory?
    @State private var dateFrom: Date = {
        let cal = Calendar.current
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        return cal.date(byAdding: .month, value: -1, to: thisMonth)!
    }()
    @State private var dateTo: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()
    @State private var selectedTransactionID: UUID?
    @State private var showingDetail = false
    @State private var transactionToDelete: Transaction?
    @State private var showDeleteConfirmation = false
    @State private var refundPairs: [(charge: Transaction, refund: Transaction)] = []
    @State private var showRefundConfirmation = false
    @State private var showNoRefundsAlert = false

    private var selectedTransaction: Transaction? {
        guard let id = selectedTransactionID else { return nil }
        return allTransactions.first { $0.id == id }
    }

    private var filteredTransactions: [Transaction] {
        allTransactions.filter { txn in
            // Date filter
            guard txn.date >= dateFrom && txn.date <= dateTo else { return false }

            // Card filter
            if let card = selectedCard, txn.card?.id != card.id { return false }

            // Category filter
            if let cat = selectedCategory, txn.category?.id != cat.id { return false }

            // Search filter
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                return txn.cleanDescription.lowercased().contains(query)
                    || txn.rawDescription.lowercased().contains(query)
            }

            return true
        }
    }

    private var totalSpend: Decimal {
        filteredTransactions.reduce(Decimal.zero) { total, txn in
            txn.isCredit ? total - abs(txn.amount) : total + txn.amount
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            TransactionFilterBar(
                searchText: $searchText,
                selectedCard: $selectedCard,
                selectedCategory: $selectedCategory,
                dateFrom: $dateFrom,
                dateTo: $dateTo,
                cards: cards,
                categories: categories
            )

            // Summary
            HStack {
                Text("\(filteredTransactions.count) transactions")
                    .foregroundStyle(.secondary)

                Button {
                    refundPairs = findRefundPairs()
                    if refundPairs.isEmpty {
                        showNoRefundsAlert = true
                    } else {
                        showRefundConfirmation = true
                    }
                } label: {
                    Label("Remove Refund Pairs", systemImage: "arrow.uturn.left.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
                Text("Total: \(CurrencyFormatter.format(totalSpend))")
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Table
            Table(of: Transaction.self, selection: $selectedTransactionID) {
                TableColumn("Date") { txn in
                    Text(DateFormatters.shortDate.string(from: txn.date))
                        .font(.caption)
                }
                .width(min: 70, ideal: 85, max: 100)

                TableColumn("Description") { txn in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(txn.cleanDescription)
                            .lineLimit(1)
                        if txn.cleanDescription != txn.rawDescription {
                            Text(txn.rawDescription)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 200, ideal: 350)

                TableColumn("Category") { txn in
                    CategoryCell(category: txn.category)
                }
                .width(min: 110, ideal: 150, max: 200)

                TableColumn("Card") { txn in
                    if let card = txn.card {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: card.colorHex))
                                .frame(width: 8, height: 8)
                            Text(card.cardName)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 80, ideal: 120, max: 160)

                TableColumn("Amount") { txn in
                    Text(CurrencyFormatter.format(txn.amount))
                        .monospacedDigit()
                        .foregroundStyle(txn.isCredit ? .green : .primary)
                }
                .width(min: 80, ideal: 100, max: 120)
            } rows: {
                ForEach(filteredTransactions) { txn in
                    TableRow(txn)
                        .contextMenu {
                            Button(role: .destructive) {
                                transactionToDelete = txn
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Transaction", systemImage: "trash")
                            }
                        }
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))
            .onChange(of: selectedTransactionID) { _, newValue in
                showingDetail = newValue != nil
            }
        }
        .inspector(isPresented: $showingDetail) {
            if let transaction = selectedTransaction {
                TransactionDetailView(
                    transaction: transaction,
                    onDelete: { deleteTransaction($0) },
                    onClose: {
                        selectedTransactionID = nil
                        showingDetail = false
                    }
                )
                .id(transaction.id)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            }
        }
        .navigationTitle("Transactions")
        .confirmationDialog(
            "Delete Transaction?",
            isPresented: $showDeleteConfirmation,
            presenting: transactionToDelete
        ) { txn in
            Button("Delete", role: .destructive) {
                deleteTransaction(txn)
            }
        } message: { txn in
            Text("Delete \"\(txn.cleanDescription)\" (\(CurrencyFormatter.format(txn.amount)))? This cannot be undone.")
        }
        .onDeleteCommand {
            if let txn = selectedTransaction {
                transactionToDelete = txn
                showDeleteConfirmation = true
            }
        }
        .sheet(isPresented: $showRefundConfirmation) {
            RefundPairsConfirmSheet(pairs: refundPairs) {
                removeRefundPairs()
            }
        }
        .alert("No Refund Pairs", isPresented: $showNoRefundsAlert) {
            Button("OK") {}
        } message: {
            Text("No matching charge + refund pairs found in the current filtered transactions.")
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        if selectedTransactionID == transaction.id {
            selectedTransactionID = nil
            showingDetail = false
        }
        modelContext.delete(transaction)
        try? modelContext.save()
    }

    /// Find matching charge + refund pairs among filtered transactions.
    /// A refund is identified by `isCredit == true` or negative amount.
    /// Matches by same card and identical absolute amount.
    private func findRefundPairs() -> [(charge: Transaction, refund: Transaction)] {
        let refunds = filteredTransactions.filter { $0.isCredit || $0.amount < 0 }
        var pairs: [(charge: Transaction, refund: Transaction)] = []
        var usedIDs: Set<UUID> = []

        for refund in refunds {
            let refundAmount = abs(refund.amount)
            let refundCard = refund.card?.id

            // Find a matching charge: same card, same absolute amount
            if let match = filteredTransactions.first(where: {
                !usedIDs.contains($0.id)
                && $0.id != refund.id
                && !$0.isCredit
                && $0.amount > 0
                && abs($0.amount) == refundAmount
                && $0.card?.id == refundCard
            }) {
                pairs.append((charge: match, refund: refund))
                usedIDs.insert(match.id)
                usedIDs.insert(refund.id)
            }
        }

        return pairs
    }

    private func removeRefundPairs() {
        for pair in refundPairs {
            if selectedTransactionID == pair.charge.id || selectedTransactionID == pair.refund.id {
                selectedTransactionID = nil
                showingDetail = false
            }
            modelContext.delete(pair.charge)
            modelContext.delete(pair.refund)
        }
        refundPairs = []
        try? modelContext.save()
    }
}

// MARK: - Refund Pairs Confirm Sheet

private struct RefundPairsConfirmSheet: View {
    let pairs: [(charge: Transaction, refund: Transaction)]
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Refund Pairs Found")
                    .font(.title2.bold())
                Spacer()
                Text("\(pairs.count) pairs (\(pairs.count * 2) transactions)")
                    .foregroundStyle(.secondary)
            }
            .padding()

            Table(of: RefundPairRow.self) {
                TableColumn("Charge") { row in
                    Text(row.chargeName)
                        .lineLimit(1)
                }
                .width(min: 150, ideal: 200)

                TableColumn("Refund") { row in
                    Text(row.refundName)
                        .lineLimit(1)
                        .foregroundStyle(.green)
                }
                .width(min: 150, ideal: 200)

                TableColumn("Card") { row in
                    Text(row.cardName)
                        .font(.caption)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Amount") { row in
                    Text(CurrencyFormatter.format(row.amount))
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 90)
            } rows: {
                ForEach(rows) { row in
                    TableRow(row)
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Remove All \(pairs.count) Pairs", role: .destructive) {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var rows: [RefundPairRow] {
        pairs.map { pair in
            RefundPairRow(
                id: pair.charge.id,
                chargeName: pair.charge.cleanDescription,
                refundName: pair.refund.cleanDescription,
                cardName: pair.charge.card?.cardName ?? "Unknown",
                amount: abs(pair.charge.amount)
            )
        }
    }
}

private struct RefundPairRow: Identifiable {
    let id: UUID
    let chargeName: String
    let refundName: String
    let cardName: String
    let amount: Decimal
}

// MARK: - Category Cell with hover

private struct CategoryCell: View {
    let category: SpendingCategory?
    @State private var isHovered = false

    var body: some View {
        Group {
            if let category {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: category.colorHex))
                        .frame(width: 10, height: 10)
                    Text(category.name)
                        .lineLimit(1)
                }
                .font(isHovered ? .callout.bold() : .caption)
                .padding(.vertical, 2)
                .padding(.horizontal, isHovered ? 6 : 0)
                .background(
                    isHovered ? Color(hex: category.colorHex).opacity(0.15) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
            } else {
                Text("Uncategorized")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

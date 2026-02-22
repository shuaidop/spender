import SwiftUI

struct ImportReviewView: View {
    let statement: ParsedStatement
    let card: Card?
    let duplicateIDs: Set<UUID>
    let onConfirm: ([ParsedTransaction]) -> Void
    let onCancel: () -> Void

    @State private var selectedIDs: Set<UUID>

    init(statement: ParsedStatement, card: Card?, duplicateIDs: Set<UUID> = [],
         onConfirm: @escaping ([ParsedTransaction]) -> Void, onCancel: @escaping () -> Void) {
        self.statement = statement
        self.card = card
        self.duplicateIDs = duplicateIDs
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        // Auto-deselect duplicates
        let allIDs = Set(statement.transactions.map(\.id))
        self._selectedIDs = State(initialValue: allIDs.subtracting(duplicateIDs))
    }

    private var selectedTransactions: [ParsedTransaction] {
        statement.transactions.filter { selectedIDs.contains($0.id) }
    }

    private var newCount: Int {
        statement.transactions.count - duplicateIDs.count
    }

    var body: some View {
        VStack(spacing: 16) {
            // Summary header
            HStack {
                VStack(alignment: .leading) {
                    Text("Review Parsed Transactions")
                        .font(.title2.bold())

                    HStack(spacing: 16) {
                        Label(statement.statementMonth, systemImage: "calendar")
                        if let card {
                            Label(card.displayName, systemImage: "creditcard")
                        }
                        Label("\(statement.transactions.count) transactions", systemImage: "list.number")
                        Label(
                            CurrencyFormatter.format(totalAmount),
                            systemImage: "dollarsign.circle"
                        )
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Select all / deselect all
                Button(selectedIDs.count == statement.transactions.count ? "Deselect All" : "Select All") {
                    if selectedIDs.count == statement.transactions.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(statement.transactions.map(\.id))
                    }
                }
                .buttonStyle(.bordered)
            }

            // Duplicate warning
            if !duplicateIDs.isEmpty {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundStyle(.blue)
                    Text("\(duplicateIDs.count) duplicate\(duplicateIDs.count == 1 ? "" : "s") already imported — auto-deselected. \(newCount) new.")
                        .font(.caption)
                }
                .padding(8)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            // Warnings
            if !statement.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(statement.warnings, id: \.self) { warning in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(warning)
                                .font(.caption)
                        }
                    }
                }
                .padding(8)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            // Transaction list with checkboxes
            List {
                ForEach(statement.transactions) { txn in
                    let isDuplicate = duplicateIDs.contains(txn.id)
                    HStack(spacing: 12) {
                        // Checkbox
                        Image(systemName: selectedIDs.contains(txn.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIDs.contains(txn.id) ? Color.accentColor : .secondary)
                            .font(.title3)
                            .onTapGesture {
                                if selectedIDs.contains(txn.id) {
                                    selectedIDs.remove(txn.id)
                                } else {
                                    selectedIDs.insert(txn.id)
                                }
                            }

                        // Duplicate badge
                        if isDuplicate {
                            Text("DUP")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.orange, in: RoundedRectangle(cornerRadius: 3))
                        }

                        // Date
                        Text(DateFormatters.shortDate.string(from: txn.date))
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)

                        // Description
                        Text(txn.rawDescription)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Amount
                        Text(CurrencyFormatter.format(txn.amount))
                            .monospacedDigit()
                            .foregroundStyle(txn.isCredit ? .green : .primary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .opacity(isDuplicate && !selectedIDs.contains(txn.id) ? 0.5 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedIDs.contains(txn.id) {
                            selectedIDs.remove(txn.id)
                        } else {
                            selectedIDs.insert(txn.id)
                        }
                    }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))

            // Action buttons
            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("\(selectedIDs.count) of \(statement.transactions.count) selected")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Button("Import \(selectedIDs.count) Transactions") {
                    onConfirm(selectedTransactions)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedIDs.isEmpty)
            }
        }
        .padding()
    }

    private var totalAmount: Decimal {
        selectedTransactions
            .filter { !$0.isCredit }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
}

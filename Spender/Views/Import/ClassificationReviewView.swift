import SwiftUI
import SwiftData

struct ClassificationReviewView: View {
    let transactions: [Transaction]
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]
    /// Selections keyed by normalized merchant pattern
    @State private var selections: [String: String] = [:]

    /// Group transactions by normalized merchant pattern
    private var merchantGroups: [(pattern: String, displayName: String, transactions: [Transaction], totalAmount: Decimal)] {
        var groups: [String: [Transaction]] = [:]
        var order: [String] = []

        for txn in transactions {
            let pattern = ClassificationEngine.normalizePattern(txn.rawDescription)
            if groups[pattern] == nil {
                order.append(pattern)
            }
            groups[pattern, default: []].append(txn)
        }

        return order.compactMap { pattern in
            guard let txns = groups[pattern] else { return nil }
            let displayName = txns.first?.cleanDescription ?? txns.first?.rawDescription ?? pattern
            let total = txns.filter { !$0.isCredit }.reduce(Decimal.zero) { $0 + $1.amount }
            return (pattern: pattern, displayName: displayName, transactions: txns, totalAmount: total)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Classify Uncategorized Transactions")
                        .font(.title2.bold())
                    Text("\(merchantGroups.count) merchants (\(transactions.count) transactions) need your input — pick a category for each merchant.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            List {
                ForEach(merchantGroups, id: \.pattern) { group in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(group.displayName)
                                    .lineLimit(1)
                                if group.transactions.count > 1 {
                                    Text("\(group.transactions.count)x")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(.secondary, in: RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            if let raw = group.transactions.first?.rawDescription,
                               raw != group.displayName {
                                Text(raw)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(CurrencyFormatter.format(group.totalAmount))
                            .monospacedDigit()
                            .frame(width: 90, alignment: .trailing)

                        Picker("Category", selection: categoryBinding(for: group.pattern)) {
                            Text("Uncategorized").tag("")
                            Divider()
                            ForEach(categories) { cat in
                                Text(cat.name).tag(cat.name)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))

            HStack {
                Button("Skip — Keep Uncategorized") {
                    onDone()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                let classified = selections.values.filter { !$0.isEmpty }.count
                Text("\(classified) of \(merchantGroups.count) merchants classified")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Button("Save Classifications") {
                    saveClassifications()
                    onDone()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private func categoryBinding(for pattern: String) -> Binding<String> {
        Binding(
            get: { selections[pattern] ?? "" },
            set: { selections[pattern] = $0 }
        )
    }

    private func saveClassifications() {
        let engine = ClassificationEngine(modelContext: modelContext)

        for group in merchantGroups {
            guard let catName = selections[group.pattern], !catName.isEmpty,
                  let cat = categories.first(where: { $0.name == catName }) else { continue }

            // overrideCategory propagates to ALL matching transactions (not just the ones in this import)
            if let representative = group.transactions.first {
                engine.overrideCategory(for: representative, to: cat)
            }
        }
        try? modelContext.save()
    }
}

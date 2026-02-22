import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Bindable var transaction: Transaction
    var onDelete: ((Transaction) -> Void)?
    var onClose: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]

    @State private var selectedCategoryID: UUID?
    @State private var editedDescription: String = ""
    @State private var notes: String = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Amount
                Text(CurrencyFormatter.format(transaction.amount))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(transaction.isCredit ? .green : .primary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Divider()

                // Editable description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)

                    TextField("Description", text: $editedDescription)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        .onSubmit {
                            saveDescription()
                        }

                    let linkedCount = countLinkedTransactions()
                    if linkedCount > 1 {
                        Text("Applies to \(linkedCount) transactions with this merchant")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if transaction.cleanDescription != transaction.rawDescription {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Original")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(transaction.rawDescription)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }

                // Other details
                Group {
                    DetailRow(label: "Date", value: DateFormatters.mediumDate.string(from: transaction.date))
                    if let card = transaction.card {
                        DetailRow(label: "Card", value: card.displayName)
                    }
                    DetailRow(label: "Statement", value: DateFormatters.monthKeyToDisplay(transaction.monthKey))
                }

                Divider()

                // Category picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.headline)

                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Uncategorized").tag(nil as UUID?)
                        Divider()
                        ForEach(categories) { cat in
                            Label(cat.name, systemImage: cat.iconName).tag(cat.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedCategoryID) { _, newValue in
                        guard newValue != transaction.category?.id else { return }
                        guard let categoryID = newValue,
                              let category = categories.first(where: { $0.id == categoryID }) else {
                            transaction.category = nil
                            try? modelContext.save()
                            return
                        }
                        transaction.category = category
                        transaction.categoryOverridden = true
                        let engine = ClassificationEngine(modelContext: modelContext)
                        engine.overrideCategory(for: transaction, to: category)
                    }

                    if transaction.categoryOverridden {
                        Text("Manually classified")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Divider()

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)

                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        .onChange(of: notes) { _, newValue in
                            transaction.notes = newValue.isEmpty ? nil : newValue
                            try? modelContext.save()
                        }
                }

                if onDelete != nil {
                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Transaction", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .confirmationDialog("Delete Transaction?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete?(transaction)
            }
        } message: {
            Text("Delete \"\(transaction.cleanDescription)\"? This cannot be undone.")
        }
        .onAppear {
            selectedCategoryID = transaction.category?.id
            editedDescription = transaction.cleanDescription
            notes = transaction.notes ?? ""
        }
    }

    private func countLinkedTransactions() -> Int {
        let pattern = ClassificationEngine.normalizePattern(transaction.rawDescription)
        let descriptor = FetchDescriptor<Transaction>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { ClassificationEngine.normalizePattern($0.rawDescription) == pattern }.count
    }

    private func saveDescription() {
        let trimmed = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != transaction.cleanDescription else { return }

        let engine = ClassificationEngine(modelContext: modelContext)
        engine.overrideDescription(for: transaction, to: trimmed)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let transactionID: UUID

    @Query private var transactions: [Transaction]
    @State private var showCategoryPicker = false

    private var transaction: Transaction? {
        transactions.first { $0.id == transactionID }
    }

    var body: some View {
        Group {
            if let txn = transaction {
                List {
                    Section("Details") {
                        LabeledContent("Merchant", value: txn.merchantName ?? "Unknown")
                        LabeledContent("Description", value: txn.originalDescription)
                        LabeledContent("Amount") {
                            Text(txn.amount, format: .currency(code: txn.isoCurrencyCode))
                                .fontWeight(.semibold)
                        }
                        LabeledContent("Date", value: txn.date.formatted(date: .long, time: .omitted))
                        if txn.isPending {
                            LabeledContent("Status", value: "Pending")
                                .foregroundStyle(.orange)
                        }
                    }

                    Section("Category") {
                        LabeledContent("Current Category", value: txn.effectiveCategory)

                        if let aiCategory = txn.aiCategory {
                            LabeledContent("AI Category", value: aiCategory)
                            if let confidence = txn.aiCategoryConfidence {
                                LabeledContent("Confidence") {
                                    Text("\(Int(confidence * 100))%")
                                }
                            }
                        }

                        Button("Override Category") {
                            showCategoryPicker = true
                        }
                    }

                    if let account = txn.account {
                        Section("Account") {
                            LabeledContent("Institution", value: account.institutionName)
                            LabeledContent("Account", value: "\(account.accountName) (\(account.mask))")
                        }
                    }
                }
                .navigationTitle("Transaction")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showCategoryPicker) {
                    CategoryPickerSheet(transaction: txn)
                }
            } else {
                ContentUnavailableView("Transaction Not Found", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let transaction: Transaction

    var body: some View {
        NavigationStack {
            List {
                ForEach(Constants.categoryNames, id: \.self) { category in
                    Button {
                        transaction.userOverrideCategory = category
                        transaction.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        HStack {
                            Text(category)
                            Spacer()
                            if transaction.effectiveCategory == category {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

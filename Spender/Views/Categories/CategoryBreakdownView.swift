import SwiftUI
import SwiftData

struct CategoryBreakdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Transaction> { !$0.isPending },
        sort: \Transaction.date,
        order: .reverse
    )
    private var transactions: [Transaction]

    @State private var selectedPeriod: PeriodType = .month

    private let chartFactory = DefaultChartFactory()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Period", selection: $selectedPeriod) {
                        Text("Week").tag(PeriodType.week)
                        Text("Month").tag(PeriodType.month)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if !categoryData.isEmpty {
                        chartFactory.makeCategoryChart(data: categoryData)
                            .padding(.horizontal)

                        LazyVStack(spacing: 0) {
                            ForEach(categoryData) { item in
                                NavigationLink(value: item.category) {
                                    CategoryRow(item: item, total: totalSpend)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        EmptyStateView(
                            icon: "chart.pie",
                            title: "No Data",
                            message: "Sync transactions to see your spending breakdown."
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Categories")
            .navigationDestination(for: String.self) { category in
                CategoryDetailView(category: category)
            }
        }
    }

    private var periodTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        let start: Date

        switch selectedPeriod {
        case .week:
            start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .month:
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        }

        return transactions.filter { $0.date >= start }
    }

    private var totalSpend: Decimal {
        periodTransactions.reduce(0) { $0 + $1.amount }
    }

    private var categoryData: [CategorySpend] {
        var grouped: [String: Decimal] = [:]
        var counts: [String: Int] = [:]
        for txn in periodTransactions {
            let cat = txn.effectiveCategory
            grouped[cat, default: 0] += txn.amount
            counts[cat, default: 0] += 1
        }
        return grouped
            .map { CategorySpend(category: $0.key, amount: $0.value, color: .blue, transactionCount: counts[$0.key] ?? 0) }
            .sorted { $0.amount > $1.amount }
    }
}

private struct CategoryRow: View {
    let item: CategorySpend
    let total: Decimal

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return NSDecimalNumber(decimal: item.amount).doubleValue / NSDecimalNumber(decimal: total).doubleValue * 100
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(item.transactionCount) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.amount, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(Int(percentage))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

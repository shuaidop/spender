import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Transaction> { !$0.isPending },
        sort: \Transaction.date,
        order: .reverse
    )
    private var transactions: [Transaction]

    @State private var selectedPeriod: PeriodType = .week

    private let chartFactory = DefaultChartFactory()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period picker
                    Picker("Period", selection: $selectedPeriod) {
                        Text("Week").tag(PeriodType.week)
                        Text("Month").tag(PeriodType.month)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Total spend card
                    SpendingSummaryCard(
                        totalSpend: totalForPeriod,
                        transactionCount: transactionsForPeriod.count,
                        periodLabel: selectedPeriod.label
                    )

                    // Weekly chart
                    if !weeklyChartData.isEmpty {
                        VStack(alignment: .leading) {
                            Text("This Week")
                                .font(.headline)
                                .padding(.horizontal)
                            chartFactory.makeWeeklyChart(data: weeklyChartData)
                                .padding(.horizontal)
                        }
                    }

                    // Top categories
                    if !topCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Categories")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(topCategories.prefix(3), id: \.category) { item in
                                HStack {
                                    Text(item.category)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(
                                        item.amount,
                                        format: .currency(code: "USD")
                                    )
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    if transactions.isEmpty {
                        EmptyStateView(
                            icon: "creditcard",
                            title: "No Transactions Yet",
                            message: "Connect a bank account in Settings to start tracking your spending."
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }

    // MARK: - Computed Data

    private var transactionsForPeriod: [Transaction] {
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

    private var totalForPeriod: Decimal {
        transactionsForPeriod.reduce(0) { $0 + $1.amount }
    }

    private var weeklyChartData: [DailySpend] {
        let calendar = Calendar.current
        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()

        return transactions
            .filter { $0.date >= weekStart }
            .map { DailySpend(date: $0.date, amount: $0.amount, category: $0.effectiveCategory) }
    }

    private var topCategories: [CategorySpend] {
        var grouped: [String: Decimal] = [:]
        var counts: [String: Int] = [:]
        for txn in transactionsForPeriod {
            let cat = txn.effectiveCategory
            grouped[cat, default: 0] += txn.amount
            counts[cat, default: 0] += 1
        }
        return grouped
            .map { CategorySpend(category: $0.key, amount: $0.value, color: .blue, transactionCount: counts[$0.key] ?? 0) }
            .sorted { $0.amount > $1.amount }
    }
}

enum PeriodType: String, CaseIterable {
    case week
    case month

    var label: String {
        switch self {
        case .week: "This Week"
        case .month: "This Month"
        }
    }
}

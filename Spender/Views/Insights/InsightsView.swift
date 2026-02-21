import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(
        filter: #Predicate<Transaction> { !$0.isPending },
        sort: \Transaction.date,
        order: .reverse
    )
    private var transactions: [Transaction]

    @Query(sort: \SpendingSummary.periodStart, order: .reverse)
    private var summaries: [SpendingSummary]

    private let chartFactory = DefaultChartFactory()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // AI Summary
                    if let latestSummary = summaries.first, let text = latestSummary.aiSummaryText {
                        QuickInsightCard(insightText: text)
                    }

                    // Optimization suggestions
                    if let suggestions = summaries.first?.aiSuggestions, !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggestions")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(suggestions, id: \.self) { suggestion in
                                OptimizationSuggestionCard(suggestion: suggestion)
                            }
                        }
                    }

                    // Monthly trend
                    if !monthlyData.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Monthly Spending")
                                .font(.headline)
                                .padding(.horizontal)
                            chartFactory.makeMonthlyChart(data: monthlyData)
                                .padding(.horizontal)
                        }
                    }

                    // Weekly trend
                    if !trendData.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Weekly Trend")
                                .font(.headline)
                                .padding(.horizontal)
                            chartFactory.makeTrendChart(data: trendData)
                                .padding(.horizontal)
                        }
                    }

                    if transactions.isEmpty {
                        EmptyStateView(
                            icon: "lightbulb",
                            title: "No Insights Yet",
                            message: "Sync your transactions to get AI-powered spending insights."
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
        }
    }

    private var monthlyData: [MonthlySpend] {
        let calendar = Calendar.current
        var grouped: [Date: Decimal] = [:]

        for txn in transactions {
            let components = calendar.dateComponents([.year, .month], from: txn.date)
            if let monthStart = calendar.date(from: components) {
                grouped[monthStart, default: 0] += txn.amount
            }
        }

        return grouped
            .map { MonthlySpend(month: $0.key, totalSpend: $0.value) }
            .sorted { $0.month < $1.month }
            .suffix(6)
            .map { $0 }
    }

    private var trendData: [WeeklyTotal] {
        let calendar = Calendar.current
        var grouped: [Date: Decimal] = [:]

        for txn in transactions {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: txn.date)
            if let weekStart = calendar.date(from: components) {
                grouped[weekStart, default: 0] += txn.amount
            }
        }

        return grouped
            .map { WeeklyTotal(weekStart: $0.key, total: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
            .suffix(12)
            .map { $0 }
    }
}

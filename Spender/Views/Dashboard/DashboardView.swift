import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    /// Query to trigger SwiftUI re-render when transactions change
    @Query private var allTransactions: [Transaction]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var yearStart: Date {
        Calendar.current.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
    }

    private var yearEnd: Date {
        Calendar.current.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1))!
    }

    var body: some View {
        let engine = AnalysisEngine(modelContext: modelContext)
        let summary = engine.summaryStats(from: yearStart, to: yearEnd)
        let byCategory = engine.spendingByCategory(from: yearStart, to: yearEnd)
        let monthlyTotals = engine.monthlyTotals(year: selectedYear)
        let topMerchants = engine.topMerchants(from: yearStart, to: yearEnd, limit: 5)
        let credits = engine.creditDetails(from: yearStart, to: yearEnd)
        let netSpending = summary.totalSpend - summary.creditTotal

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Overview")
                        .font(.title.bold())
                    Spacer()
                    Picker("Year", selection: $selectedYear) {
                        ForEach((2020...Calendar.current.component(.year, from: Date())), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 120)
                }

                // Annual summary cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 16) {
                    StatCard(title: "Total Spent", value: CurrencyFormatter.format(summary.totalSpend), icon: "dollarsign.circle.fill", color: .red)
                    StatCard(title: "Credits/Payments", value: CurrencyFormatter.format(summary.creditTotal), icon: "arrow.down.circle.fill", color: .green)
                    StatCard(title: "Net Spending", value: CurrencyFormatter.format(netSpending), icon: "equal.circle.fill", color: .indigo)
                    StatCard(title: "Transactions", value: "\(summary.transactionCount) + \(summary.creditCount)", icon: "list.number", color: .blue)
                    StatCard(title: "Monthly Avg", value: CurrencyFormatter.format(monthlyAverage(monthlyTotals)), icon: "chart.line.uptrend.xyaxis", color: .orange)
                }

                // Monthly trend chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monthly Spending — \(String(selectedYear))")
                        .font(.headline)

                    if monthlyTotals.isEmpty || monthlyTotals.allSatisfy({ $0.totalAmount == 0 }) {
                        ContentUnavailableView("No Data", systemImage: "chart.bar",
                            description: Text("Import statements to see monthly trends."))
                            .frame(height: 200)
                    } else {
                        Chart(monthlyTotals) { month in
                            BarMark(
                                x: .value("Month", month.monthLabel),
                                y: .value("Amount", Double(truncating: month.totalAmount as NSDecimalNumber))
                            )
                            .foregroundStyle(.blue.gradient)
                            .cornerRadius(4)
                        }
                        .chartYAxis {
                            AxisMarks(format: .currency(code: "USD"))
                        }
                        .frame(height: 220)
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                // Two-column: categories + top merchants
                HStack(alignment: .top, spacing: 16) {
                    // Category donut chart
                    CategoryDonutChart(byCategory: byCategory)

                    // Top merchants
                    VStack(alignment: .leading) {
                        Text("Top Merchants")
                            .font(.headline)

                        if topMerchants.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "building.2", description: Text("Import statements to see top merchants."))
                                .frame(height: 250)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(topMerchants) { merchant in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(merchant.merchantName)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                            Text("\(merchant.transactionCount) transactions")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(CurrencyFormatter.format(merchant.totalAmount))
                                            .font(.subheadline.bold())
                                            .monospacedDigit()
                                    }
                                    if merchant.id != topMerchants.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }

                // Credits & Payments section
                if !credits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                            Text("Credits & Payments — \(String(selectedYear))")
                                .font(.headline)
                            Spacer()
                            Text("Total: \(CurrencyFormatter.format(summary.creditTotal))")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(credits) { credit in
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.left")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(credit.merchantName)
                                            .font(.caption)
                                            .lineLimit(1)
                                        if credit.transactionCount > 1 {
                                            Text("\(credit.transactionCount) transactions")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(CurrencyFormatter.format(credit.totalAmount))
                                        .font(.caption.bold())
                                        .monospacedDigit()
                                        .foregroundStyle(.green)
                                }
                                .padding(8)
                                .background(Color.green.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }

                // Monthly cards grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Month-by-Month")
                        .font(.headline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(Array(monthlyTotals.enumerated()), id: \.element.id) { index, month in
                            let prevMonth = index > 0 ? monthlyTotals[index - 1] : nil
                            MonthCard(month: month, previousMonth: prevMonth)
                        }
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .padding()
        }
    }

    private func monthlyAverage(_ totals: [MonthlyTotal]) -> Decimal {
        let nonZero = totals.filter { $0.totalAmount > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(Decimal.zero) { $0 + $1.totalAmount } / Decimal(nonZero.count)
    }
}

// MARK: - Month Card

private struct MonthCard: View {
    let month: MonthlyTotal
    let previousMonth: MonthlyTotal?

    private var change: Double? {
        guard let prev = previousMonth, prev.totalAmount > 0, month.totalAmount > 0 else { return nil }
        return Double(truncating: ((month.totalAmount - prev.totalAmount) / prev.totalAmount * 100) as NSDecimalNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(month.monthLabel)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(month.totalAmount > 0 ? CurrencyFormatter.format(month.totalAmount) : "—")
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(month.totalAmount > 0 ? .primary : .tertiary)

            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%+.0f%%", change))
                        .font(.caption2)
                }
                .foregroundStyle(change >= 0 ? .red : .green)
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(month.totalAmount > 0 ? Color.blue.opacity(0.04) : Color.clear,
                     in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Category Donut Chart with Hover

struct CategoryDonutChart: View {
    let byCategory: [CategorySpending]
    var onCategoryTap: ((String) -> Void)?
    @State private var selectedCategory: String?

    private var selectedItem: CategorySpending? {
        guard let name = selectedCategory else { return nil }
        return byCategory.first { $0.categoryName == name }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Spending by Category")
                .font(.headline)

            if byCategory.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.pie", description: Text("Import statements to see your spending breakdown."))
                    .frame(height: 250)
            } else {
                ZStack {
                    Chart(byCategory) { item in
                        SectorMark(
                            angle: .value("Amount", Double(truncating: item.totalAmount as NSDecimalNumber)),
                            innerRadius: .ratio(0.6),
                            outerRadius: selectedCategory == item.categoryName ? .ratio(1.0) : .ratio(0.92),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color(hex: item.colorHex))
                        .opacity(selectedCategory == nil || selectedCategory == item.categoryName ? 1.0 : 0.4)
                        .cornerRadius(4)
                    }
                    .chartAngleSelection(value: $selectedCategory)
                    .chartBackground { _ in
                        // Center label showing selected category details
                        if let item = selectedItem {
                            VStack(spacing: 4) {
                                Text(item.categoryName)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Text(CurrencyFormatter.format(item.totalAmount))
                                    .font(.title3.bold())
                                    .monospacedDigit()
                                Text(String(format: "%.1f%%", item.percentage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(item.transactionCount) txns")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(height: 250)
                }
                .animation(.easeInOut(duration: 0.15), value: selectedCategory)

                // Legend with hover + click interaction
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(byCategory) { cat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: cat.colorHex))
                                .frame(width: 8, height: 8)
                            Text(cat.categoryName)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(CurrencyFormatter.format(cat.totalAmount))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", cat.percentage))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            if onCategoryTap != nil {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .background(
                            selectedCategory == cat.categoryName
                                ? Color(hex: cat.colorHex).opacity(0.15)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            selectedCategory = hovering ? cat.categoryName : nil
                        }
                        .onTapGesture {
                            onCategoryTap?(cat.categoryName)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

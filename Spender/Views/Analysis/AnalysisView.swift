import SwiftUI
import SwiftData
import Charts

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    /// Query to trigger SwiftUI re-render when transactions change
    @Query private var allTransactions: [Transaction]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedTab: AnalysisTab = .monthly

    private var startDate: Date {
        Calendar.current.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
    }

    private var endDate: Date {
        Calendar.current.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1))!
    }

    enum AnalysisTab: String, CaseIterable {
        case monthly = "Monthly"
        case categories = "Categories"
        case cards = "Cards"
        case trends = "Trends"
        case tips = "Optimization"
        case annual = "Annual Report"
    }

    var body: some View {
        let engine = AnalysisEngine(modelContext: modelContext)

        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Analysis")
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
            .padding()

            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(AnalysisTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            // Content
            ScrollView {
                switch selectedTab {
                case .monthly:
                    MonthlyDetailView(engine: engine, year: selectedYear)
                case .categories:
                    CategoryBreakdownView(engine: engine, startDate: startDate, endDate: endDate)
                case .cards:
                    CardComparisonView(engine: engine, startDate: startDate, endDate: endDate)
                case .trends:
                    MonthlyTrendsView(engine: engine, year: selectedYear)
                case .tips:
                    OptimizationTipsView(engine: engine, startDate: startDate, endDate: endDate)
                case .annual:
                    AnnualSummaryView(engine: engine, year: selectedYear)
                }
            }
            .padding()
        }
    }
}

// MARK: - Monthly Detail View

struct MonthlyDetailView: View {
    let engine: AnalysisEngine
    let year: Int
    @State private var selectedMonth: Int = {
        let m = Calendar.current.component(.month, from: Date()) - 1
        return m < 1 ? 12 : m // default to last month
    }()
    @State private var showReport = false
    @State private var drilldownCategory: String?

    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private var monthStart: Date {
        Calendar.current.date(from: DateComponents(year: year, month: selectedMonth, day: 1))!
    }

    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthStart)!
    }

    var body: some View {
        let monthlyTotals = engine.monthlyTotals(year: year)
        let summary = engine.summaryStats(from: monthStart, to: monthEnd)
        let byCategory = engine.spendingByCategory(from: monthStart, to: monthEnd)
        let topMerchants = engine.topMerchants(from: monthStart, to: monthEnd, limit: 10)
        let credits = engine.creditDetails(from: monthStart, to: monthEnd)

        VStack(alignment: .leading, spacing: 20) {
            // Month selector grid
            Text("Select Month — \(String(year))")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    let monthData = monthlyTotals.first(where: { $0.monthKey == String(format: "%04d-%02d", year, month) })
                    let total = monthData?.totalAmount ?? 0
                    let creditAmt = monthData?.creditAmount ?? 0
                    let hasData = total > 0 || creditAmt > 0

                    Button {
                        selectedMonth = month
                    } label: {
                        VStack(spacing: 4) {
                            Text(monthNames[month - 1])
                                .font(.caption.bold())
                            Text(hasData ? CurrencyFormatter.format(total) : "—")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(hasData ? .primary : .tertiary)
                            if creditAmt > 0 {
                                Text("-\(CurrencyFormatter.format(creditAmt))")
                                    .font(.system(size: 9))
                                    .monospacedDigit()
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedMonth == month
                                ? Color.accentColor.opacity(0.15)
                                : hasData ? Color.secondary.opacity(0.06) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedMonth == month ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Selected month header with report button
            HStack {
                Text("\(monthNames[selectedMonth - 1]) \(String(year))")
                    .font(.title2.bold())
                Spacer()
                if summary.transactionCount > 0 || summary.creditCount > 0 {
                    Button {
                        showReport = true
                    } label: {
                        Label("Generate Report", systemImage: "doc.text")
                    }
                    Button {
                        let generator = AnnualReportGenerator(engine: engine)
                        let report = generator.generateMonthly(year: year, month: selectedMonth)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(report, forType: .string)
                    } label: {
                        Label("Copy Report", systemImage: "doc.on.doc")
                    }
                }
            }

            if summary.transactionCount == 0 && summary.creditCount == 0 {
                ContentUnavailableView("No Data", systemImage: "calendar.badge.exclamationmark",
                    description: Text("No transactions found for \(monthNames[selectedMonth - 1]) \(String(year))."))
            } else {
                // Summary row — 6 cards including credits and net
                let netSpending = summary.totalSpend - summary.creditTotal
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible()),
                ], spacing: 12) {
                    MonthStatCard(title: "Total Spent", value: CurrencyFormatter.format(summary.totalSpend), color: .red)
                    MonthStatCard(title: "Credits/Payments", value: CurrencyFormatter.format(summary.creditTotal), color: .green)
                    MonthStatCard(title: "Net Spending", value: CurrencyFormatter.format(netSpending), color: .indigo)
                    MonthStatCard(title: "Transactions", value: "\(summary.transactionCount) + \(summary.creditCount)", color: .blue)
                    MonthStatCard(title: "Daily Avg", value: CurrencyFormatter.format(summary.averageDaily), color: .orange)
                    MonthStatCard(title: "Highest", value: CurrencyFormatter.format(summary.highestSingle), color: .purple)
                }

                // Two-column layout: category donut with hover + click drill-down + top merchants
                HStack(alignment: .top, spacing: 16) {
                    CategoryDonutChart(byCategory: byCategory) { categoryName in
                        drilldownCategory = categoryName
                    }

                    // Top merchants
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Merchants")
                            .font(.subheadline.bold())

                        if topMerchants.isEmpty {
                            Text("No data").foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(topMerchants.enumerated()), id: \.element.id) { index, merchant in
                                HStack(spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(merchant.merchantName)
                                            .font(.caption)
                                            .lineLimit(1)
                                        if let cat = merchant.categoryName {
                                            Text(cat)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(CurrencyFormatter.format(merchant.totalAmount))
                                            .font(.caption)
                                            .monospacedDigit()
                                        Text("\(merchant.transactionCount) txns")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if index < topMerchants.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                }

                // Credits & Payments section
                if !credits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                            Text("Credits & Payments")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("Total: \(CurrencyFormatter.format(summary.creditTotal))")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        ForEach(credits) { credit in
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.left")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(credit.merchantName)
                                        .font(.caption)
                                        .lineLimit(1)
                                    if let cat = credit.categoryName {
                                        Text(cat)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(CurrencyFormatter.format(credit.totalAmount))
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(.green)
                                    if credit.transactionCount > 1 {
                                        Text("\(credit.transactionCount) txns")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green.opacity(0.15), lineWidth: 1)
                    )
                }

                // Month-over-month comparison
                if selectedMonth > 1 {
                    let prevStart = Calendar.current.date(from: DateComponents(year: year, month: selectedMonth - 1, day: 1))!
                    let prevEnd = monthStart
                    let prevSummary = engine.summaryStats(from: prevStart, to: prevEnd)

                    if prevSummary.transactionCount > 0 {
                        let change = summary.totalSpend - prevSummary.totalSpend
                        let pctChange = prevSummary.totalSpend > 0
                            ? Double(truncating: (change / prevSummary.totalSpend * 100) as NSDecimalNumber)
                            : 0.0

                        HStack(spacing: 12) {
                            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(change > 0 ? .red : .green)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("vs \(monthNames[selectedMonth - 2])")
                                    .font(.caption.bold())
                                HStack(spacing: 4) {
                                    Text(change > 0 ? "+" : "")
                                        .font(.caption) +
                                    Text(CurrencyFormatter.format(abs(change)))
                                        .font(.caption.bold())
                                    Text("(\(String(format: "%+.1f%%", pctChange)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(monthNames[selectedMonth - 2])
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(CurrencyFormatter.format(prevSummary.totalSpend))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(monthNames[selectedMonth - 1])
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(CurrencyFormatter.format(summary.totalSpend))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        }
                        .padding()
                        .background(
                            (change > 0 ? Color.red : Color.green).opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showReport) {
            MonthlyReportSheet(monthName: monthNames[selectedMonth - 1], year: year, engine: engine, month: selectedMonth)
        }
        .sheet(item: $drilldownCategory) { categoryName in
            CategoryTransactionsSheet(
                engine: engine,
                categoryName: categoryName,
                startDate: monthStart,
                endDate: monthEnd,
                monthLabel: "\(monthNames[selectedMonth - 1]) \(String(year))"
            )
        }
    }
}

private struct MonthlyReportSheet: View {
    let monthName: String
    let year: Int
    let engine: AnalysisEngine
    let month: Int

    @Environment(\.dismiss) private var dismiss
    @State private var report: String = ""
    @State private var llmAnalysis: String = ""
    @State private var isAnalyzing = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Monthly Report — \(monthName) \(String(year))")
                    .font(.title2.bold())
                Spacer()
                Button {
                    Task { await analyzeWithLLM() }
                } label: {
                    Label("AI Analysis", systemImage: "brain")
                }
                .disabled(isAnalyzing || report.isEmpty)
                Button {
                    NSPasteboard.general.clearContents()
                    let copyText = llmAnalysis.isEmpty ? report : report + "\n\n---\n\n" + llmAnalysis
                    NSPasteboard.general.setString(copyText, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(report.isEmpty)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if report.isEmpty {
                        ProgressView("Generating report...")
                    } else {
                        MarkdownView(text: report)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if isAnalyzing {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Analyzing with AI...")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }

                    if !llmAnalysis.isEmpty {
                        Divider()
                        Text("AI Analysis")
                            .font(.headline)
                        MarkdownView(text: llmAnalysis)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            let generator = AnnualReportGenerator(engine: engine)
            report = generator.generateMonthly(year: year, month: month)
        }
    }

    private func analyzeWithLLM() async {
        let service = OpenAIService()
        guard service.isConfigured else {
            llmAnalysis = "OpenAI API key not configured. Go to Settings > API Key."
            return
        }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            llmAnalysis = try await service.chat(
                systemPrompt: """
                You are a personal finance analyst reviewing a real monthly credit card spending report. Analyze the data carefully and provide your response in **markdown format**.

                Rules:
                - Only reference numbers, categories, and merchants that actually appear in the report
                - Do NOT invent or assume any data not present in the report
                - All dollar amounts and percentages you cite must come directly from the report
                - Be specific and actionable

                Structure your response as:

                ## Key Insights
                (2-3 most important observations from the actual data)

                ## Areas of Concern
                (Categories or merchants where spending seems high, with specific amounts)

                ## Positive Observations
                (Good patterns you notice)

                ## Specific Recommendations
                (Actionable suggestions tied to the actual spending data, with estimated savings)
                """,
                userMessage: report
            )
        } catch {
            llmAnalysis = "Error: \(error.localizedDescription)"
        }
    }
}

private struct CategoryTransactionsSheet: View {
    let engine: AnalysisEngine
    let categoryName: String
    let startDate: Date
    let endDate: Date
    let monthLabel: String

    @Environment(\.dismiss) private var dismiss

    private var transactions: [Transaction] {
        engine.transactions(from: startDate, to: endDate)
            .filter { txn in
                let catName = txn.category?.name ?? "Uncategorized"
                return catName == categoryName
            }
            .sorted { $0.date < $1.date }
    }

    private var charges: [Transaction] {
        transactions.filter { !$0.isCredit }
    }

    private var credits: [Transaction] {
        transactions.filter { $0.isCredit }
    }

    private var totalAmount: Decimal {
        charges.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(categoryName)
                        .font(.title2.bold())
                    Text("\(monthLabel) — \(charges.count) charges totaling \(CurrencyFormatter.format(totalAmount))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Transaction table
            Table(of: Transaction.self) {
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
                .width(min: 200, ideal: 300)

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
                ForEach(transactions) { txn in
                    TableRow(txn)
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))
        }
        .frame(minWidth: 650, minHeight: 400)
    }
}

private struct MonthStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Category Breakdown

struct CategoryBreakdownView: View {
    let engine: AnalysisEngine
    let startDate: Date
    let endDate: Date

    var body: some View {
        let data = engine.spendingByCategory(from: startDate, to: endDate)

        VStack(alignment: .leading, spacing: 16) {
            if data.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar", description: Text("No transactions in this period."))
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Amount", Double(truncating: item.totalAmount as NSDecimalNumber)),
                        y: .value("Category", item.categoryName)
                    )
                    .foregroundStyle(Color(hex: item.colorHex))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(format: .currency(code: "USD"))
                }
                .frame(height: CGFloat(max(data.count * 36, 200)))

                // Detail table
                ForEach(data) { cat in
                    HStack {
                        Image(systemName: cat.iconName)
                            .foregroundStyle(Color(hex: cat.colorHex))
                            .frame(width: 24)
                        Text(cat.categoryName)
                            .frame(width: 140, alignment: .leading)
                        Text(CurrencyFormatter.format(cat.totalAmount))
                            .monospacedDigit()
                            .frame(width: 100, alignment: .trailing)
                        Text(String(format: "%.1f%%", cat.percentage))
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        Text("\(cat.transactionCount) txns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
        }
    }
}

// MARK: - Card Comparison

struct CardComparisonView: View {
    let engine: AnalysisEngine
    let startDate: Date
    let endDate: Date

    var body: some View {
        let data = engine.spendingByCard(from: startDate, to: endDate)

        VStack(alignment: .leading, spacing: 16) {
            if data.isEmpty {
                ContentUnavailableView("No Data", systemImage: "creditcard", description: Text("No transactions in this period."))
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Card", item.cardName),
                        y: .value("Amount", Double(truncating: item.totalAmount as NSDecimalNumber))
                    )
                    .foregroundStyle(Color(hex: item.colorHex))
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(format: .currency(code: "USD"))
                }
                .frame(height: 300)

                ForEach(data) { card in
                    HStack {
                        Circle()
                            .fill(Color(hex: card.colorHex))
                            .frame(width: 12, height: 12)
                        Text(card.cardName)
                        Spacer()
                        Text(CurrencyFormatter.format(card.totalAmount))
                            .monospacedDigit()
                            .bold()
                        Text("(\(card.transactionCount) txns)")
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
    }
}

// MARK: - Monthly Trends

struct MonthlyTrendsView: View {
    let engine: AnalysisEngine
    let year: Int

    var body: some View {
        let data = engine.monthlyTotals(year: year)

        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Spending - \(String(year))")
                .font(.headline)

            Chart(data) { month in
                LineMark(
                    x: .value("Month", month.monthLabel),
                    y: .value("Amount", Double(truncating: month.totalAmount as NSDecimalNumber))
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Month", month.monthLabel),
                    y: .value("Amount", Double(truncating: month.totalAmount as NSDecimalNumber))
                )
                .foregroundStyle(.blue.opacity(0.1))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Month", month.monthLabel),
                    y: .value("Amount", Double(truncating: month.totalAmount as NSDecimalNumber))
                )
                .foregroundStyle(.blue)
            }
            .chartYAxis {
                AxisMarks(format: .currency(code: "USD"))
            }
            .frame(height: 300)

            // Table
            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible()),
            ], spacing: 8) {
                ForEach(data) { month in
                    VStack {
                        Text(month.monthLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(month.totalAmount))
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    }
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Optimization Tips

struct OptimizationTipsView: View {
    let engine: AnalysisEngine
    let startDate: Date
    let endDate: Date

    var body: some View {
        let generator = OptimizationTipGenerator(engine: engine)
        let tips = generator.generateTips(from: startDate, to: endDate)

        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Optimization Tips")
                .font(.headline)

            if tips.isEmpty {
                ContentUnavailableView("No Tips", systemImage: "lightbulb", description: Text("Import more data to get optimization suggestions."))
            } else {
                ForEach(tips) { tip in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: tipIcon(tip.severity))
                                .foregroundStyle(tipColor(tip.severity))
                                .font(.title3)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title)
                                    .font(.subheadline.bold())
                                Text(tip.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !tip.details.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(tip.details, id: \.self) { detail in
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.leading, 36)
                        }

                        if let savings = tip.potentialSavings {
                            Text("Potential savings: \(CurrencyFormatter.format(savings))")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .padding(.leading, 36)
                        }
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                }
            }
        }
    }

    private func tipIcon(_ severity: OptimizationTip.Severity) -> String {
        switch severity {
        case .warning: "exclamationmark.triangle.fill"
        case .suggestion: "lightbulb.fill"
        case .info: "info.circle.fill"
        }
    }

    private func tipColor(_ severity: OptimizationTip.Severity) -> Color {
        switch severity {
        case .warning: .red
        case .suggestion: .orange
        case .info: .blue
        }
    }
}

// MARK: - Annual Summary

struct AnnualSummaryView: View {
    let engine: AnalysisEngine
    let year: Int

    @State private var report: String = ""
    @State private var isGenerating = false
    @State private var llmAnalysis: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Annual Report — \(String(year))")
                    .font(.headline)
                Spacer()
                Button {
                    generateReport()
                } label: {
                    Label("Generate Report", systemImage: "doc.text")
                }

                Button {
                    Task { await analyzeWithLLM() }
                } label: {
                    Label("AI Analysis", systemImage: "brain")
                }
                .disabled(report.isEmpty || isGenerating)

                Button {
                    NSPasteboard.general.clearContents()
                    let copyText = llmAnalysis.isEmpty ? report : report + "\n\n---\n\n" + llmAnalysis
                    NSPasteboard.general.setString(copyText, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(report.isEmpty)
            }

            if report.isEmpty {
                ContentUnavailableView(
                    "No Report",
                    systemImage: "doc.text",
                    description: Text("Click 'Generate Report' to create an annual spending report.")
                )
            } else {
                // Report rendered as markdown
                GroupBox("Spending Report") {
                    ScrollView {
                        MarkdownView(text: report)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 400)
                }

                // LLM Analysis rendered as markdown
                if !llmAnalysis.isEmpty {
                    GroupBox("AI Analysis") {
                        ScrollView {
                            MarkdownView(text: llmAnalysis)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 400)
                    }
                }

                if isGenerating {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing with AI...")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
        }
    }

    private func generateReport() {
        let generator = AnnualReportGenerator(engine: engine)
        report = generator.generate(year: year)
    }

    private func analyzeWithLLM() async {
        let service = OpenAIService()
        guard service.isConfigured else {
            llmAnalysis = "OpenAI API key not configured. Go to Settings > API Key."
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        do {
            llmAnalysis = try await service.chat(
                systemPrompt: """
                You are a personal finance analyst. Analyze the following annual spending report and provide your response in **markdown format** with clear headings and bullet points:

                ## Key Insights & Patterns
                ## Areas of Concern
                ## Positive Trends
                ## Cost-Saving Recommendations
                (Include specific, actionable suggestions with estimated dollar savings)
                ## Month-by-Month Narrative

                Be specific with numbers and percentages. Use **bold** for key figures and *italics* for emphasis.
                """,
                userMessage: report
            )
        } catch {
            llmAnalysis = "Error: \(error.localizedDescription)"
        }
    }
}

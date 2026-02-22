import SwiftUI
import SwiftData

struct DevToolsView: View {
    @State private var selectedTab: DevTab = .overview

    enum DevTab: String, CaseIterable {
        case overview = "Overview"
        case cache = "Classification Cache"
        case transactions = "Transactions"
        case sessions = "Import Sessions"
        case cards = "Cards"
        case categories = "Categories"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Developer Tools")
                    .font(.title.bold())
                Spacer()
            }
            .padding()

            Picker("View", selection: $selectedTab) {
                ForEach(DevTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            switch selectedTab {
            case .overview:
                DevOverviewView()
            case .cache:
                CacheBrowserView()
            case .transactions:
                TransactionBrowserView()
            case .sessions:
                SessionBrowserView()
            case .cards:
                CardBrowserView()
            case .categories:
                CategoryBrowserView()
            }
        }
    }
}

// MARK: - Overview (Stats + Bulk Delete)

struct DevOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var importSessions: [ImportSession]
    @Query private var cacheEntries: [ClassificationCache]
    @Query private var categories: [SpendingCategory]
    @Query private var cards: [Card]
    @Query private var chatMessages: [ChatMessage]
    @State private var showDeleteConfirmation = false
    @State private var deleteAction: (() -> Void)?
    @State private var deleteMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Database Statistics") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Transactions", value: "\(transactions.count)")
                        LabeledContent("Import Sessions", value: "\(importSessions.count)")
                        LabeledContent("Classification Cache", value: "\(cacheEntries.count)")
                        LabeledContent("Categories", value: "\(categories.count)")
                        LabeledContent("Cards", value: "\(cards.count)")
                        LabeledContent("Chat Messages", value: "\(chatMessages.count)")
                    }
                    .padding(4)
                }

                GroupBox("Bulk Delete") {
                    VStack(alignment: .leading, spacing: 10) {
                        confirmButton("Delete All Transactions (\(transactions.count))", disabled: transactions.isEmpty) {
                            for txn in transactions { modelContext.delete(txn) }
                            for session in importSessions { modelContext.delete(session) }
                            try? modelContext.save()
                        }

                        confirmButton("Clear Classification Cache (\(cacheEntries.count))", disabled: cacheEntries.isEmpty) {
                            for entry in cacheEntries { modelContext.delete(entry) }
                            try? modelContext.save()
                        }

                        confirmButton("Delete All Chat History (\(chatMessages.count))", disabled: chatMessages.isEmpty) {
                            for msg in chatMessages { modelContext.delete(msg) }
                            try? modelContext.save()
                        }

                        confirmButton("Delete All Cards (\(cards.count))", disabled: cards.isEmpty) {
                            for card in cards { modelContext.delete(card) }
                            try? modelContext.save()
                        }

                        confirmButton("Reset Categories to Defaults", disabled: false) {
                            for cat in categories { modelContext.delete(cat) }
                            try? modelContext.save()
                            for (index, def) in SpendingCategory.defaults.enumerated() {
                                let cat = SpendingCategory(name: def.name, iconName: def.icon, colorHex: def.color, sortOrder: index)
                                modelContext.insert(cat)
                            }
                            try? modelContext.save()
                        }

                        Divider()

                        confirmButton("NUKE: Delete Everything", disabled: false) {
                            for txn in transactions { modelContext.delete(txn) }
                            for session in importSessions { modelContext.delete(session) }
                            for entry in cacheEntries { modelContext.delete(entry) }
                            for msg in chatMessages { modelContext.delete(msg) }
                            for card in cards { modelContext.delete(card) }
                            for cat in categories { modelContext.delete(cat) }
                            try? modelContext.save()
                        }
                    }
                    .padding(4)
                }

                GroupBox("Storage") {
                    VStack(alignment: .leading, spacing: 6) {
                        let dbPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("default.store").path ?? "unknown"
                        LabeledContent("DB Path") {
                            Text(dbPath)
                                .font(.caption2)
                                .textSelection(.enabled)
                                .lineLimit(1)
                        }

                        HStack(spacing: 12) {
                            Button("Open DB Folder in Finder") {
                                if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                                    NSWorkspace.shared.open(url)
                                }
                            }

                            Button("Clear UserDefaults") {
                                if let bundleId = Bundle.main.bundleIdentifier {
                                    UserDefaults.standard.removePersistentDomain(forName: bundleId)
                                }
                            }
                        }
                    }
                    .padding(4)
                }
            }
            .padding()
        }
        .alert("Confirm Delete", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { deleteAction = nil }
            Button("Delete", role: .destructive) {
                deleteAction?()
                deleteAction = nil
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private func confirmButton(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, role: .destructive) {
            deleteMessage = "Are you sure? This cannot be undone."
            deleteAction = action
            showDeleteConfirmation = true
        }
        .disabled(disabled)
    }
}

// MARK: - Classification Cache Browser

struct CacheBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClassificationCache.lastUsed, order: .reverse) private var entries: [ClassificationCache]
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]
    @State private var searchText = ""
    @State private var editingEntry: ClassificationCache?

    private var filtered: [ClassificationCache] {
        if searchText.isEmpty { return entries }
        let q = searchText.lowercased()
        return entries.filter {
            $0.merchantPattern.contains(q) ||
            $0.cleanName.lowercased().contains(q) ||
            $0.categoryName.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search cache...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                Spacer()
                Text("\(filtered.count) entries")
                    .foregroundStyle(.secondary)
            }
            .padding()

            Table(of: ClassificationCache.self) {
                TableColumn("Raw Pattern") { entry in
                    Text(entry.merchantPattern)
                        .font(.caption)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                .width(min: 200, ideal: 300)

                TableColumn("Clean Name") { entry in
                    Text(entry.cleanName)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 100, ideal: 160)

                TableColumn("Category") { entry in
                    Text(entry.categoryName)
                        .font(.caption)
                }
                .width(min: 80, ideal: 130)

                TableColumn("Last Used") { entry in
                    Text(DateFormatters.shortDate.string(from: entry.lastUsed))
                        .font(.caption)
                }
                .width(min: 70, ideal: 85)

                TableColumn("Actions") { entry in
                    HStack(spacing: 8) {
                        Button {
                            editingEntry = entry
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)

                        Button {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .width(60)
            } rows: {
                ForEach(filtered) { entry in
                    TableRow(entry)
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))
        }
        .sheet(item: $editingEntry) { entry in
            CacheEditSheet(entry: entry, categories: categories.map(\.name)) {
                editingEntry = nil
            }
        }
    }
}

struct CacheEditSheet: View {
    @Bindable var entry: ClassificationCache
    let categories: [String]
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var cleanName: String = ""
    @State private var categoryName: String = ""
    @State private var affectedCount: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Cache Entry")
                .font(.headline)

            Form {
                LabeledContent("Raw Pattern") {
                    Text(entry.merchantPattern)
                        .textSelection(.enabled)
                }

                TextField("Clean Name", text: $cleanName)

                Picker("Category", selection: $categoryName) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }

                if affectedCount > 0 {
                    Text("Will update \(affectedCount) matching transaction\(affectedCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save & Update All") {
                    saveAndPropagate()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear {
            cleanName = entry.cleanName
            categoryName = entry.categoryName
            affectedCount = countMatchingTransactions()
        }
    }

    private func countMatchingTransactions() -> Int {
        let pattern = entry.merchantPattern
        let descriptor = FetchDescriptor<Transaction>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.rawDescription.lowercased() == pattern }.count
    }

    private func saveAndPropagate() {
        // Update cache entry
        entry.cleanName = cleanName
        entry.categoryName = categoryName
        entry.lastUsed = Date()

        // Find the target category
        let catName = categoryName
        let catDescriptor = FetchDescriptor<SpendingCategory>(
            predicate: #Predicate<SpendingCategory> { $0.name == catName }
        )
        let targetCategory = (try? modelContext.fetch(catDescriptor))?.first

        // Propagate to all transactions with matching raw description
        let pattern = entry.merchantPattern
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = (try? modelContext.fetch(descriptor)) ?? []
        for txn in allTransactions where txn.rawDescription.lowercased() == pattern {
            txn.cleanDescription = cleanName
            if let targetCategory {
                txn.category = targetCategory
            }
        }

        try? modelContext.save()
    }
}

// MARK: - Transaction Browser

struct TransactionBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]
    @State private var searchText = ""
    @State private var editingTransaction: Transaction?

    private var filtered: [Transaction] {
        if searchText.isEmpty { return transactions }
        let q = searchText.lowercased()
        return transactions.filter {
            $0.rawDescription.lowercased().contains(q) ||
            $0.cleanDescription.lowercased().contains(q) ||
            $0.category?.name.lowercased().contains(q) == true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search transactions...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                Spacer()
                Text("\(filtered.count) transactions")
                    .foregroundStyle(.secondary)
            }
            .padding()

            Table(of: Transaction.self) {
                TableColumn("Date") { txn in
                    Text(DateFormatters.shortDate.string(from: txn.date))
                        .font(.caption)
                }
                .width(min: 70, ideal: 85)

                TableColumn("Raw Description") { txn in
                    Text(txn.rawDescription)
                        .font(.caption)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                .width(min: 150, ideal: 250)

                TableColumn("Clean Name") { txn in
                    Text(txn.cleanDescription)
                        .font(.caption)
                        .lineLimit(1)
                }
                .width(min: 100, ideal: 150)

                TableColumn("Category") { txn in
                    Text(txn.category?.name ?? "—")
                        .font(.caption)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Amount") { txn in
                    Text(CurrencyFormatter.format(txn.amount))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(txn.isCredit ? .green : .primary)
                }
                .width(min: 70, ideal: 90)

                TableColumn("Card") { txn in
                    Text(txn.card?.cardName ?? "—")
                        .font(.caption)
                }
                .width(min: 60, ideal: 90)

                TableColumn("") { txn in
                    HStack(spacing: 8) {
                        Button {
                            editingTransaction = txn
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)

                        Button {
                            modelContext.delete(txn)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .width(60)
            } rows: {
                ForEach(filtered) { txn in
                    TableRow(txn)
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))
        }
        .sheet(item: $editingTransaction) { txn in
            TransactionEditSheet(transaction: txn, categories: categories) {
                editingTransaction = nil
            }
        }
    }
}

struct TransactionEditSheet: View {
    @Bindable var transaction: Transaction
    let categories: [SpendingCategory]
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var cleanDescription: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var notes: String = ""
    @State private var applyToAll: Bool = true
    @State private var matchCount: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Transaction")
                .font(.headline)

            Form {
                LabeledContent("Date") {
                    Text(DateFormatters.shortDate.string(from: transaction.date))
                }
                LabeledContent("Raw Description") {
                    Text(transaction.rawDescription)
                        .textSelection(.enabled)
                }
                TextField("Clean Name", text: $cleanDescription)
                LabeledContent("Amount") {
                    Text(CurrencyFormatter.format(transaction.amount))
                        .foregroundStyle(transaction.isCredit ? .green : .primary)
                }
                Picker("Category", selection: $selectedCategoryName) {
                    Text("Uncategorized").tag("")
                    ForEach(categories) { cat in
                        Text(cat.name).tag(cat.name)
                    }
                }
                TextField("Notes", text: $notes)

                if matchCount > 1 {
                    Toggle("Apply to all \(matchCount) matching transactions", isOn: $applyToAll)
                        .font(.caption)
                }
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(applyToAll && matchCount > 1 ? "Save & Update All" : "Save") {
                    saveAndPropagate()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            cleanDescription = transaction.cleanDescription
            selectedCategoryName = transaction.category?.name ?? ""
            notes = transaction.notes ?? ""
            matchCount = countMatchingTransactions()
        }
    }

    private func countMatchingTransactions() -> Int {
        let raw = transaction.rawDescription.lowercased()
        let descriptor = FetchDescriptor<Transaction>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.rawDescription.lowercased() == raw }.count
    }

    private func saveAndPropagate() {
        let targetCategory = categories.first(where: { $0.name == selectedCategoryName })

        // Update this transaction
        transaction.cleanDescription = cleanDescription
        transaction.notes = notes.isEmpty ? nil : notes
        if let targetCategory {
            transaction.category = targetCategory
            transaction.categoryOverridden = true
        }

        // Propagate to all matching transactions
        if applyToAll && matchCount > 1 {
            let raw = transaction.rawDescription.lowercased()
            let descriptor = FetchDescriptor<Transaction>()
            let allTransactions = (try? modelContext.fetch(descriptor)) ?? []
            for txn in allTransactions where txn.rawDescription.lowercased() == raw && txn.id != transaction.id {
                txn.cleanDescription = cleanDescription
                if let targetCategory {
                    txn.category = targetCategory
                    txn.categoryOverridden = true
                }
            }
        }

        // Update classification cache
        let normalized = transaction.rawDescription.lowercased()
        let cacheDescriptor = FetchDescriptor<ClassificationCache>(
            predicate: #Predicate<ClassificationCache> { $0.merchantPattern == normalized }
        )
        if let existing = (try? modelContext.fetch(cacheDescriptor))?.first {
            existing.cleanName = cleanDescription
            if let targetCategory {
                existing.categoryName = targetCategory.name
            }
            existing.lastUsed = Date()
        } else if let targetCategory {
            let cache = ClassificationCache(
                merchantPattern: normalized,
                cleanName: cleanDescription,
                categoryName: targetCategory.name
            )
            modelContext.insert(cache)
        }

        try? modelContext.save()
    }
}

// MARK: - Session Browser

struct SessionBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ImportSession.importDate, order: .reverse) private var sessions: [ImportSession]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(sessions.count) import sessions")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()

            Table(of: ImportSession.self) {
                TableColumn("Import Date") { session in
                    Text(DateFormatters.shortDate.string(from: session.importDate))
                        .font(.caption)
                }
                .width(min: 80, ideal: 100)

                TableColumn("File") { session in
                    Text(session.fileName)
                        .font(.caption)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                .width(min: 150, ideal: 250)

                TableColumn("Bank") { session in
                    Text(session.bankName)
                        .font(.caption)
                }
                .width(min: 60, ideal: 100)

                TableColumn("Month") { session in
                    Text(session.statementMonth)
                        .font(.caption)
                }
                .width(min: 60, ideal: 100)

                TableColumn("Txns") { session in
                    Text("\(session.transactionCount)")
                        .font(.caption)
                        .monospacedDigit()
                }
                .width(min: 40, ideal: 60)

                TableColumn("Total") { session in
                    Text(CurrencyFormatter.format(session.totalAmount))
                        .font(.caption)
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 90)

                TableColumn("") { session in
                    Button {
                        modelContext.delete(session)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .width(30)
            } rows: {
                ForEach(sessions) { session in
                    TableRow(session)
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))
        }
    }
}

// MARK: - Card Browser

struct CardBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.bankName) private var cards: [Card]
    @State private var editingCard: Card?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(cards.count) cards")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()

            Table(of: Card.self) {
                TableColumn("Bank") { card in
                    Text(card.bankName)
                        .font(.caption)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Card Name") { card in
                    Text(card.cardName)
                        .font(.caption)
                }
                .width(min: 100, ideal: 160)

                TableColumn("Last 4") { card in
                    Text(card.lastFourDigits)
                        .font(.caption.monospaced())
                }
                .width(min: 50, ideal: 60)

                TableColumn("Type") { card in
                    Text(card.cardType)
                        .font(.caption)
                }
                .width(min: 50, ideal: 70)

                TableColumn("Color") { card in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: card.colorHex))
                            .frame(width: 12, height: 12)
                        Text(card.colorHex)
                            .font(.caption)
                    }
                }
                .width(min: 80, ideal: 100)

                TableColumn("Txns") { card in
                    Text("\(card.transactions.count)")
                        .font(.caption)
                        .monospacedDigit()
                }
                .width(min: 40, ideal: 60)

                TableColumn("") { card in
                    HStack(spacing: 8) {
                        Button {
                            editingCard = card
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)

                        Button {
                            modelContext.delete(card)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .width(60)
            } rows: {
                ForEach(cards) { card in
                    TableRow(card)
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))
        }
        .sheet(item: $editingCard) { card in
            CardEditSheet(card: card) {
                editingCard = nil
            }
        }
    }
}

struct CardEditSheet: View {
    @Bindable var card: Card
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var bankName = ""
    @State private var cardName = ""
    @State private var lastFour = ""
    @State private var colorHex = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Card")
                .font(.headline)

            Form {
                TextField("Bank Name", text: $bankName)
                TextField("Card Name", text: $cardName)
                TextField("Last 4 Digits", text: $lastFour)
                TextField("Color Hex", text: $colorHex)
                HStack {
                    Text("Preview:")
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 20, height: 20)
                }
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    card.bankName = bankName
                    card.cardName = cardName
                    card.lastFourDigits = lastFour
                    card.colorHex = colorHex
                    try? modelContext.save()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            bankName = card.bankName
            cardName = card.cardName
            lastFour = card.lastFourDigits
            colorHex = card.colorHex
        }
    }
}

// MARK: - Category Browser

struct CategoryBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]
    @State private var editingCategory: SpendingCategory?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(categories.count) categories")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()

            Table(of: SpendingCategory.self) {
                TableColumn("Icon") { cat in
                    Image(systemName: cat.iconName)
                        .foregroundStyle(Color(hex: cat.colorHex))
                }
                .width(30)

                TableColumn("Name") { cat in
                    Text(cat.name)
                        .font(.caption)
                }
                .width(min: 100, ideal: 160)

                TableColumn("Icon Name") { cat in
                    Text(cat.iconName)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .width(min: 100, ideal: 140)

                TableColumn("Color") { cat in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: cat.colorHex))
                            .frame(width: 12, height: 12)
                        Text(cat.colorHex)
                            .font(.caption)
                    }
                }
                .width(min: 80, ideal: 100)

                TableColumn("Order") { cat in
                    Text("\(cat.sortOrder)")
                        .font(.caption)
                        .monospacedDigit()
                }
                .width(40)

                TableColumn("Txns") { cat in
                    Text("\(cat.transactions.count)")
                        .font(.caption)
                        .monospacedDigit()
                }
                .width(min: 40, ideal: 60)

                TableColumn("") { cat in
                    HStack(spacing: 8) {
                        Button {
                            editingCategory = cat
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)

                        Button {
                            modelContext.delete(cat)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .width(60)
            } rows: {
                ForEach(categories) { cat in
                    TableRow(cat)
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))
        }
        .sheet(item: $editingCategory) { cat in
            CategoryEditSheet(category: cat) {
                editingCategory = nil
            }
        }
    }
}

struct CategoryEditSheet: View {
    @Bindable var category: SpendingCategory
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var iconName = ""
    @State private var colorHex = ""
    @State private var sortOrder = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Category")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                TextField("SF Symbol Name", text: $iconName)
                HStack {
                    Text("Preview:")
                    Image(systemName: iconName)
                        .foregroundStyle(Color(hex: colorHex))
                }
                TextField("Color Hex", text: $colorHex)
                HStack {
                    Text("Color:")
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 20, height: 20)
                }
                Stepper("Sort Order: \(sortOrder)", value: $sortOrder, in: 0...100)
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    category.name = name
                    category.iconName = iconName
                    category.colorHex = colorHex
                    category.sortOrder = sortOrder
                    try? modelContext.save()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            name = category.name
            iconName = category.iconName
            colorHex = category.colorHex
            sortOrder = category.sortOrder
        }
    }
}

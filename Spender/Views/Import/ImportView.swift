import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.bankName) private var cards: [Card]

    @State private var selectedFiles: [URL] = []
    @State private var selectedCard: Card?
    @State private var isImporting = false
    @State private var isDragging = false
    @State private var parsedStatement: ParsedStatement?
    @State private var parseError: String?
    @State private var showCardConfirmation = false
    @State private var showReview = false
    @State private var importProgress: String = ""
    @State private var uncategorizedTransactions: [Transaction] = []
    @State private var showClassificationReview = false
    @State private var duplicateTransactionIDs: Set<UUID> = []

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Import Statements")
                        .font(.title.bold())
                    Spacer()
                }
                .padding()

                if showClassificationReview {
                    ClassificationReviewView(transactions: uncategorizedTransactions) {
                        showClassificationReview = false
                        uncategorizedTransactions = []
                        resetState()
                    }
                } else if showReview, let statement = parsedStatement {
                    ImportReviewView(
                        statement: statement,
                        card: selectedCard,
                        duplicateIDs: duplicateTransactionIDs,
                        onConfirm: { selected in Task { await saveTransactions(selected) } },
                        onCancel: { resetState() }
                    )
                } else if showCardConfirmation {
                    cardConfirmationView
                } else {
                    importFormView
                }
            }

            // Full-screen progress overlay during save/classification
            if isImporting && showReview {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(importProgress)
                            .font(.headline)
                        Text("This may take a moment...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isImporting)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noCardsView: some View {
        ContentUnavailableView(
            "No Cards Configured",
            systemImage: "creditcard",
            description: Text("Add a credit card in Settings before importing statements.")
        )
    }

    private var importFormView: some View {
        VStack(spacing: 24) {
            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isDragging ? Color.accentColor.opacity(0.05) : Color.clear)
                    )

                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("Drop PDF or Excel statements here")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("or")
                        .foregroundStyle(.tertiary)

                    Button("Choose Files...") {
                        openFilePicker()
                    }
                    .buttonStyle(.borderedProminent)

                    if !selectedFiles.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(selectedFiles, id: \.absoluteString) { url in
                                HStack {
                                    Image(systemName: "doc.fill")
                                    Text(url.lastPathComponent)
                                        .lineLimit(1)
                                    Button {
                                        selectedFiles.removeAll { $0 == url }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            .onDrop(of: [.pdf, .spreadsheet, .data], isTargeted: $isDragging) { providers in
                handleDrop(providers)
                return true
            }

            // Error display
            if let error = parseError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            // Import progress
            if isImporting {
                ProgressView(importProgress)
                    .padding()
            }

            // Import button
            Button {
                Task { await parseFiles() }
            } label: {
                Label("Parse Statements", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedFiles.isEmpty || isImporting)

            Spacer()
        }
        .padding()
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf, UTType.spreadsheet,
                                     UTType(filenameExtension: "xlsx")].compactMap { $0 }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select credit card statement files (PDF or Excel)"

        if panel.runModal() == .OK {
            selectedFiles = panel.urls
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            // Try loading as file URL
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let urlString = String(data: data, encoding: .utf8),
                   let url = URL(string: urlString) {
                    let ext = url.pathExtension.lowercased()
                    guard ext == "pdf" || ext == "xlsx" || ext == "xls" else { return }
                    DispatchQueue.main.async {
                        if !selectedFiles.contains(url) {
                            selectedFiles.append(url)
                        }
                    }
                }
            }
        }
    }

    @State private var detectedBankName: String?
    @State private var editCardName: String = ""
    @State private var editCardColor: String = ""

    private static let cardColors = [
        "#007AFF", "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
        "#FFEAA7", "#DDA0DD", "#F7DC6F", "#FF6F61",
        "#C5A44E", "#2E7D32", "#1565C0", "#006FCF",
        "#1A237E", "#003B70", "#D03027", "#FF6F00", "#607D8B"
    ]

    private var cardConfirmationView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("Confirm Card")
                    .font(.title2.bold())

                Text("Verify the card detected from your statement")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Card picker
                if cards.count > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select Card")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Card", selection: Binding(
                            get: { selectedCard },
                            set: { newCard in
                                selectedCard = newCard
                                if let card = newCard {
                                    editCardName = card.cardName
                                    editCardColor = card.colorHex
                                }
                            }
                        )) {
                            ForEach(cards) { card in
                                Text(card.displayName).tag(card as Card?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // Editable card name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Card Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Card Name", text: $editCardName, prompt: Text("e.g. Sapphire Preferred"))
                        .textFieldStyle(.roundedBorder)
                }

                // Bank & last 4 (read-only)
                if let card = selectedCard {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bank")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(card.bankName)
                                .font(.subheadline)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last 4 Digits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(card.lastFourDigits)
                                .font(.subheadline)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Transactions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(card.transactions.count) existing")
                                .font(.subheadline)
                        }
                    }
                }

                // Color picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Color")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 8), count: 9), spacing: 8) {
                        ForEach(Self.cardColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if color == editCardColor {
                                        Circle().stroke(.primary, lineWidth: 2)
                                    }
                                }
                                .onTapGesture { editCardColor = color }
                        }
                    }
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 500)

            if let statement = parsedStatement {
                HStack(spacing: 16) {
                    Label(statement.statementMonth, systemImage: "calendar")
                    Label("\(statement.transactions.count) transactions", systemImage: "list.number")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let error = parseError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    resetState()
                }
                .keyboardShortcut(.cancelAction)

                Button("Confirm & Review Transactions") {
                    // Save any edits to the card
                    if let card = selectedCard {
                        if card.cardName != editCardName && !editCardName.isEmpty {
                            card.cardName = editCardName
                        }
                        if card.colorHex != editCardColor {
                            card.colorHex = editCardColor
                        }
                        try? modelContext.save()
                    }
                    showCardConfirmation = false
                    showReview = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedCard == nil || editCardName.isEmpty)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if let card = selectedCard {
                editCardName = card.cardName
                editCardColor = card.colorHex
            }
        }
    }

    private func parseFiles() async {
        guard !selectedFiles.isEmpty else { return }

        isImporting = true
        parseError = nil
        detectedBankName = nil

        var allTransactions: [ParsedTransaction] = []
        var allWarnings: [String] = []
        var statementMonth = "unknown"
        var lastAccountFour: String?
        var lastCardProduct: String?

        for (index, fileURL) in selectedFiles.enumerated() {
            importProgress = "Parsing file \(index + 1) of \(selectedFiles.count)..."

            do {
                let parser: any StatementParser
                let parserType: any StatementParser.Type

                // Always auto-detect parser based on file content/type
                // (card selection is for association only, not parser selection)
                if let detected = ParserRegistry.shared.detectParser(for: fileURL) {
                    parser = detected
                    parserType = type(of: parser)
                } else {
                    allWarnings.append("Could not detect format for \(fileURL.lastPathComponent)")
                    continue
                }

                let statement = try parser.parse(fileURL: fileURL)

                // Always auto-detect card from statement
                detectedBankName = parserType.bankName
                selectedCard = resolveCard(
                    bankName: parserType.bankName,
                    accountLastDigits: statement.accountLastFour,
                    cardProductName: statement.cardProductName
                )

                allTransactions.append(contentsOf: statement.transactions)
                allWarnings.append(contentsOf: statement.warnings)

                if statement.statementMonth != "unknown" {
                    statementMonth = statement.statementMonth
                }
                if let acct = statement.accountLastFour {
                    lastAccountFour = acct
                }
                if let product = statement.cardProductName {
                    lastCardProduct = product
                }
            } catch {
                allWarnings.append("\(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if allTransactions.isEmpty {
            parseError = allWarnings.isEmpty ? "No transactions found in any file." : allWarnings.joined(separator: "\n")
            isImporting = false
            return
        }

        let merged = ParsedStatement(
            transactions: allTransactions,
            statementMonth: statementMonth,
            accountLastFour: lastAccountFour,
            cardProductName: lastCardProduct,
            openingBalance: nil,
            closingBalance: nil,
            warnings: allWarnings
        )

        // Detect duplicates against existing transactions in the database
        let existingDescriptor = FetchDescriptor<Transaction>()
        let existingTransactions = (try? modelContext.fetch(existingDescriptor)) ?? []
        let existingKeys = Set(existingTransactions.map {
            duplicateKey(date: $0.date, description: $0.rawDescription, amount: $0.amount)
        })

        duplicateTransactionIDs = Set(
            allTransactions
                .filter { existingKeys.contains(duplicateKey(date: $0.date, description: $0.rawDescription, amount: $0.amount)) }
                .map(\.id)
        )

        parsedStatement = merged

        if !allWarnings.isEmpty {
            parseError = "Warnings: \(allWarnings.joined(separator: "; "))"
        }

        isImporting = false
        showCardConfirmation = true
    }

    /// Find an existing card matching the bank + digits, or auto-create one.
    /// Supports multiple cards from the same bank (e.g. Chase Sapphire + Chase Freedom).
    private func resolveCard(bankName: String, accountLastDigits: String?, cardProductName: String? = nil) -> Card {
        let bankLower = bankName.lowercased()

        // First try exact match: same bank + same digits
        if let digits = accountLastDigits,
           let exact = cards.first(where: {
               $0.bankName.lowercased() == bankLower && $0.lastFourDigits == digits
           }) {
            // Update card name if we now have a better product name
            if let product = cardProductName, exact.cardName != product {
                exact.cardName = product
                try? modelContext.save()
            }
            return exact
        }

        // Try matching by product name (same bank + same product = card replacement with new digits)
        if let product = cardProductName,
           let productMatch = cards.first(where: {
               $0.bankName.lowercased() == bankLower && $0.cardName.lowercased() == product.lowercased()
           }) {
            if let digits = accountLastDigits {
                updateCardDigitsIfNeeded(card: productMatch, newDigits: digits)
            }
            return productMatch
        }

        // If there's only one card for this bank and no product name to distinguish,
        // treat as a replacement (backward compat for statements without product names)
        let bankCards = cards.filter { $0.bankName.lowercased() == bankLower }
        if bankCards.count == 1 && cardProductName == nil {
            let existing = bankCards[0]
            if let digits = accountLastDigits {
                updateCardDigitsIfNeeded(card: existing, newDigits: digits)
            }
            return existing
        }

        // No match — auto-create with detected product name and a distinct color
        let cardName = cardProductName ?? inferCardName(bankName: bankName)
        let existingColors = Set(bankCards.map(\.colorHex))
        let colorHex = inferCardColor(bankName: bankName, cardName: cardName, existingColors: existingColors)

        let newCard = Card(
            bankName: bankName,
            cardName: cardName,
            lastFourDigits: accountLastDigits ?? "????",
            colorHex: colorHex
        )
        modelContext.insert(newCard)
        try? modelContext.save()
        return newCard
    }

    private func inferCardName(bankName: String) -> String {
        switch bankName.lowercased() {
        case "amex", "american express": "Card"
        case "chase": "Card"
        case "citi", "citibank": "Card"
        case "capital one": "Card"
        case "discover": "Card"
        case "bank of america", "bofa": "Card"
        default: "Card"
        }
    }

    private static let fallbackColors = [
        "#007AFF", "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
        "#FFEAA7", "#DDA0DD", "#F7DC6F", "#FF6F61", "#607D8B"
    ]

    private func inferCardColor(bankName: String, cardName: String, existingColors: Set<String> = []) -> String {
        let combined = "\(bankName) \(cardName)".lowercased()

        // Try brand-specific color first
        var preferred: String?
        if combined.contains("amex") || combined.contains("american express") {
            if combined.contains("gold") { preferred = "#C5A44E" }
            else if combined.contains("green") { preferred = "#2E7D32" }
            else if combined.contains("blue") { preferred = "#1565C0" }
            else { preferred = "#006FCF" }
        } else if combined.contains("chase") {
            if combined.contains("sapphire reserve") { preferred = "#1A237E" }
            else if combined.contains("sapphire") { preferred = "#1565C0" }
            else if combined.contains("amazon") { preferred = "#232F3E" }
            else { preferred = "#1A73E8" }
        } else if combined.contains("citi") { preferred = "#003B70" }
        else if combined.contains("capital one") { preferred = "#D03027" }
        else if combined.contains("discover") { preferred = "#FF6F00" }

        // If preferred color isn't already used, use it
        if let color = preferred, !existingColors.contains(color) {
            return color
        }

        // Pick a color not already used by other cards from this bank
        if let available = Self.fallbackColors.first(where: { !existingColors.contains($0) }) {
            return available
        }

        return preferred ?? "#607D8B"
    }

    /// Update the card's last digits if the statement shows a different (newer) number.
    private func updateCardDigitsIfNeeded(card: Card, newDigits: String) {
        if card.lastFourDigits != newDigits && newDigits != "????" {
            card.lastFourDigits = newDigits
            try? modelContext.save()
        }
    }

    private func saveTransactions(_ selected: [ParsedTransaction]) async {
        isImporting = true
        importProgress = "Checking for duplicates..."

        // Fetch existing transactions to check for duplicates
        let existingDescriptor = FetchDescriptor<Transaction>()
        let existingTransactions = (try? modelContext.fetch(existingDescriptor)) ?? []
        let existingKeys = Set(existingTransactions.map { duplicateKey(date: $0.date, description: $0.rawDescription, amount: $0.amount) })

        // Filter out duplicates
        let deduplicated = selected.filter { parsed in
            !existingKeys.contains(duplicateKey(date: parsed.date, description: parsed.rawDescription, amount: parsed.amount))
        }

        let skippedCount = selected.count - deduplicated.count
        if skippedCount > 0 {
            parseError = "Skipped \(skippedCount) duplicate transaction\(skippedCount == 1 ? "" : "s")."
        }

        // Filter out autopay / payment transactions (credit card payments, not actual spending)
        let newTransactions = deduplicated.filter { !Self.isPaymentTransaction($0) }
        let paymentCount = deduplicated.count - newTransactions.count
        if paymentCount > 0 {
            let msg = "Excluded \(paymentCount) payment/autopay transaction\(paymentCount == 1 ? "" : "s")."
            parseError = parseError.map { $0 + " " + msg } ?? msg
        }

        guard !newTransactions.isEmpty else {
            parseError = "All \(selected.count) transactions already exist. Nothing to import."
            isImporting = false
            resetState()
            return
        }

        importProgress = "Saving \(newTransactions.count) transactions..."

        let fileNames = selectedFiles.map(\.lastPathComponent).joined(separator: ", ")
        let month = parsedStatement?.statementMonth ?? "unknown"
        let session = ImportSession(
            fileName: fileNames.isEmpty ? "unknown" : fileNames,
            bankName: selectedCard?.bankName ?? detectedBankName ?? "Unknown",
            statementMonth: month
        )
        modelContext.insert(session)

        var savedTransactions: [Transaction] = []

        for parsed in newTransactions {
            let transaction = Transaction(
                date: parsed.date,
                rawDescription: parsed.rawDescription,
                cleanDescription: parsed.rawDescription, // Will be cleaned by LLM
                amount: parsed.amount,
                isCredit: parsed.isCredit,
                card: selectedCard
            )
            transaction.importSession = session
            modelContext.insert(transaction)
            savedTransactions.append(transaction)
        }

        session.transactionCount = newTransactions.count
        session.totalAmount = newTransactions
            .filter { !$0.isCredit }
            .reduce(Decimal.zero) { $0 + $1.amount }

        try? modelContext.save()

        // Classify all transactions via OpenAI (name standardization + category)
        importProgress = "Classifying transactions via AI..."
        let engine = ClassificationEngine(modelContext: modelContext)
        await engine.classifyTransactions(savedTransactions)

        // Check for uncategorized transactions — ask user to classify them
        let uncategorized = savedTransactions.filter {
            $0.category == nil || $0.category?.name == "Uncategorized"
        }

        isImporting = false
        showReview = false

        if !uncategorized.isEmpty {
            uncategorizedTransactions = uncategorized
            showClassificationReview = true
        } else {
            resetState()
        }
    }

    private func duplicateKey(date: Date, description: String, amount: Decimal) -> String {
        let dateStr = DateFormatters.shortDate.string(from: date)
        return "\(dateStr)|\(description)|\(amount)"
    }

    /// Detect payment/autopay transactions that are credit card payments, not spending.
    private static func isPaymentTransaction(_ parsed: ParsedTransaction) -> Bool {
        let desc = parsed.rawDescription.uppercased()
        let patterns = [
            "AUTOPAY",
            "AUTO PAY",
            "AUTOMATIC PAYMENT",
            "PAYMENT THANK YOU",
            "PAYMENT - THANK YOU",
            "MOBILE PAYMENT",
            "ONLINE PAYMENT",
            "ACH PAYMENT",
            "EPAYMENT",
            "PAYMENT RECEIVED",
            "THANK YOU FOR YOUR PAYMENT",
        ]
        return parsed.isCredit && patterns.contains(where: { desc.contains($0) })
    }

    private func resetState() {
        selectedFiles = []
        selectedCard = nil
        detectedBankName = nil
        parsedStatement = nil
        parseError = nil
        showCardConfirmation = false
        showReview = false
        showClassificationReview = false
        uncategorizedTransactions = []
        duplicateTransactionIDs = []
        importProgress = ""
    }

}

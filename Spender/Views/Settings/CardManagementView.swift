import SwiftUI
import SwiftData

struct CardManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.bankName) private var cards: [Card]
    @State private var showingAddCard = false
    @State private var editingCard: Card?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Credit Cards")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showingAddCard = true
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
            }

            if cards.isEmpty {
                ContentUnavailableView(
                    "No Cards",
                    systemImage: "creditcard",
                    description: Text("Add your credit cards to start tracking spending.")
                )
            } else {
                List {
                    ForEach(cards) { card in
                        Button {
                            editingCard = card
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: card.colorHex))
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading) {
                                    Text(card.displayName)
                                        .font(.headline)
                                    Text(card.cardType.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(card.transactions.count) transactions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteCards)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAddCard) {
            AddCardView()
        }
        .sheet(item: $editingCard) { card in
            EditCardView(card: card)
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cards[index])
        }
        try? modelContext.save()
    }
}

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var bankName = "Chase"
    @State private var cardName = ""
    @State private var lastFour = ""
    @State private var cardType = "credit"
    @State private var colorHex = "#007AFF"

    private let banks = ["Chase", "Amex", "Citi", "Capital One", "Bank of America", "Other"]
    private let cardTypes = ["credit", "debit", "charge"]
    private let colors = ["#007AFF", "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
                          "#FFEAA7", "#DDA0DD", "#F7DC6F", "#FF6F61"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Card")
                .font(.title2.bold())

            Form {
                Picker("Bank", selection: $bankName) {
                    ForEach(banks, id: \.self) { Text($0) }
                }

                TextField("Card Name", text: $cardName, prompt: Text("e.g. Sapphire Preferred"))

                TextField("Last 4 Digits (optional)", text: $lastFour, prompt: Text("1234"))
                    .onChange(of: lastFour) { _, newValue in
                        lastFour = String(newValue.filter(\.isNumber).prefix(4))
                    }

                Picker("Type", selection: $cardType) {
                    ForEach(cardTypes, id: \.self) { Text($0.capitalized) }
                }

                HStack {
                    Text("Color")
                    Spacer()
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 20, height: 20)
                            .overlay {
                                if color == colorHex {
                                    Circle().stroke(.primary, lineWidth: 2)
                                }
                            }
                            .onTapGesture { colorHex = color }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let card = Card(
                        bankName: bankName,
                        cardName: cardName,
                        lastFourDigits: lastFour,
                        cardType: cardType,
                        colorHex: colorHex
                    )
                    modelContext.insert(card)
                    try? modelContext.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(cardName.isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 360)
    }
}

struct EditCardView: View {
    @Bindable var card: Card
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var cardName: String = ""
    @State private var cardType: String = ""
    @State private var colorHex: String = ""

    private let cardTypes = ["credit", "debit", "charge"]
    private let colors = ["#007AFF", "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
                          "#FFEAA7", "#DDA0DD", "#F7DC6F", "#FF6F61",
                          "#C5A44E", "#2E7D32", "#1565C0", "#006FCF",
                          "#1A237E", "#003B70", "#D03027", "#FF6F00", "#607D8B"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Card")
                .font(.title2.bold())

            Form {
                HStack {
                    Text("Bank")
                    Spacer()
                    Text(card.bankName)
                        .foregroundStyle(.secondary)
                }

                TextField("Card Name", text: $cardName, prompt: Text("e.g. Sapphire Preferred"))

                HStack {
                    Text("Last 4 Digits")
                    Spacer()
                    Text(card.lastFourDigits)
                        .foregroundStyle(.secondary)
                }

                Picker("Type", selection: $cardType) {
                    ForEach(cardTypes, id: \.self) { Text($0.capitalized) }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 8), count: 9), spacing: 8) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if color == colorHex {
                                        Circle().stroke(.primary, lineWidth: 2)
                                    }
                                }
                                .onTapGesture { colorHex = color }
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    card.cardName = cardName
                    card.cardType = cardType
                    card.colorHex = colorHex
                    try? modelContext.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(cardName.isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 400)
        .onAppear {
            cardName = card.cardName
            cardType = card.cardType
            colorHex = card.colorHex
        }
    }
}

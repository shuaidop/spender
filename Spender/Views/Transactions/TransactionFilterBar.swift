import SwiftUI

struct TransactionFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedCard: Card?
    @Binding var selectedCategory: SpendingCategory?
    @Binding var dateFrom: Date
    @Binding var dateTo: Date
    let cards: [Card]
    let categories: [SpendingCategory]

    var body: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transactions...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 250)

            Divider().frame(height: 20)

            // Date range
            DatePicker("From", selection: $dateFrom, displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: 120)
            Text("to")
                .foregroundStyle(.secondary)
            DatePicker("To", selection: $dateTo, displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: 120)

            Divider().frame(height: 20)

            // Card filter
            Picker("Card", selection: $selectedCard) {
                Text("All Cards").tag(nil as Card?)
                Divider()
                ForEach(cards) { card in
                    Text(card.displayName).tag(card as Card?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 180)

            // Category filter
            Picker("Category", selection: $selectedCategory) {
                Text("All Categories").tag(nil as SpendingCategory?)
                Divider()
                ForEach(categories) { cat in
                    Text(cat.name).tag(cat as SpendingCategory?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 160)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

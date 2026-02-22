import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]
    @State private var showingAddCategory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Spending Categories")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showingAddCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            }

            List {
                ForEach(categories) { category in
                    HStack {
                        Image(systemName: category.iconName)
                            .foregroundStyle(Color(hex: category.colorHex))
                            .frame(width: 24)
                        Text(category.name)
                        Spacer()
                        Text("\(category.transactions.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        if !category.isDefault {
                            Button(role: .destructive) {
                                modelContext.delete(category)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
    }
}

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var iconName = "tag.fill"
    @State private var colorHex = "#007AFF"

    private let icons = ["tag.fill", "cart.fill", "car.fill", "house.fill",
                         "heart.fill", "star.fill", "bolt.fill", "gift.fill",
                         "book.fill", "film.fill", "gamecontroller.fill", "bag.fill"]
    private let colors = ["#007AFF", "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
                          "#FFEAA7", "#DDA0DD", "#F7DC6F", "#FF6F61"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Category")
                .font(.title2.bold())

            Form {
                TextField("Name", text: $name)

                HStack {
                    Text("Icon")
                    Spacer()
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 6), spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(icon == iconName ? Color(hex: colorHex) : .secondary)
                                .onTapGesture { iconName = icon }
                        }
                    }
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
                    let category = SpendingCategory(
                        name: name,
                        iconName: iconName,
                        colorHex: colorHex,
                        isDefault: false,
                        sortOrder: 100
                    )
                    modelContext.insert(category)
                    try? modelContext.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 350)
    }
}

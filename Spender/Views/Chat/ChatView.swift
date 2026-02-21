import SwiftUI

struct ChatView: View {
    @State private var inputText = ""
    @State private var messages: [ChatMessageData] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                chatEmptyState
                            }

                            ForEach(messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(.horizontal)
                                    Spacer()
                                }
                                .id("loading")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 12) {
                    TextField("Ask about your spending...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Chat")
        }
    }

    private var chatEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Ask me about your spending")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                SuggestionChip(text: "What did I spend most on this month?")
                SuggestionChip(text: "How can I reduce my subscriptions?")
                SuggestionChip(text: "Compare this month vs last month")
            }
        }
        .padding(.top, 60)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessageData(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        // Chat functionality will be connected to OpenAI in Phase 3
        Task {
            try? await Task.sleep(for: .seconds(1))
            let response = ChatMessageData(
                role: .assistant,
                content: "Chat will be connected to OpenAI in a future update. I'll be able to analyze your spending patterns and give personalized advice."
            )
            messages.append(response)
            isLoading = false
        }
    }
}

private struct SuggestionChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary, in: Capsule())
    }
}

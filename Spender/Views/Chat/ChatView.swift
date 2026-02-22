import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chat")
                    .font(.title.bold())

                Spacer()

                Picker("Context", selection: $viewModel.contextScope) {
                    ForEach(ContextScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .frame(maxWidth: 160)

                Button {
                    viewModel.newConversation()
                } label: {
                    Label("New Chat", systemImage: "plus.bubble")
                }
            }
            .padding()

            Divider()

            if !viewModel.isConfigured {
                ContentUnavailableView(
                    "API Key Required",
                    systemImage: "key.fill",
                    description: Text("Configure your OpenAI API key in Settings to use the chat feature.")
                )
            } else {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)
                                    Text("Ask me about your spending")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 8) {
                                        SuggestionChip(text: "What are my top spending categories?", viewModel: viewModel)
                                        SuggestionChip(text: "How can I reduce my monthly expenses?", viewModel: viewModel)
                                        SuggestionChip(text: "Show me my subscription spending", viewModel: viewModel)
                                        SuggestionChip(text: "What unusual charges do you see?", viewModel: viewModel)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            }

                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            // Streaming message
                            if viewModel.isStreaming && !viewModel.currentStreamText.isEmpty {
                                ChatBubbleView(
                                    message: ChatMessage(role: "assistant", content: viewModel.currentStreamText, conversationId: viewModel.conversationId)
                                )
                                .id("streaming")
                            }

                            if viewModel.isStreaming && viewModel.currentStreamText.isEmpty {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Thinking...")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 16)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.currentStreamText) { _, _ in
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }

                // Error
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Dismiss") {
                            viewModel.errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.1))
                }

                Divider()

                // Input
                ChatInputView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 80) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(
                        isUser ? Color.accentColor : Color(.controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(isUser ? .white : .primary)

                Text(DateFormatters.shortDate.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !isUser { Spacer(minLength: 80) }
        }
    }
}

struct ChatInputView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        HStack(spacing: 8) {
            TextField("Ask about your spending...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit {
                    if !viewModel.isStreaming {
                        Task { await viewModel.sendMessage() }
                    }
                }

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming
                ? .secondary : Color.accentColor
            )
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
        }
        .padding(12)
        .background(.bar)
    }
}

struct SuggestionChip: View {
    let text: String
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        Button {
            viewModel.inputText = text
            Task { await viewModel.sendMessage() }
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

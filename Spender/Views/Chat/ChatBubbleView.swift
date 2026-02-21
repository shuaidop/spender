import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessageData

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser ? Color.blue : Color(.systemGray5),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(isUser ? .white : .primary)

                // Inline attachments
                if let attachments = message.attachments {
                    ForEach(Array(attachments.enumerated()), id: \.offset) { _, attachment in
                        ChatAttachmentView(attachment: attachment)
                    }
                }

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

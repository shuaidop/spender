import SwiftUI

struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let content):
                    Text(content)
                        .font(headingFont(level))
                        .padding(.top, level == 1 ? 12 : 8)
                        .padding(.bottom, 2)

                case .paragraph(let content):
                    renderInline(content)
                        .padding(.vertical, 2)

                case .bulletItem(let content):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)
                        renderInline(content)
                    }
                    .padding(.leading, 12)

                case .numberedItem(let num, let content):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(num).")
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        renderInline(content)
                    }
                    .padding(.leading, 8)

                case .separator:
                    Divider()
                        .padding(.vertical, 4)

                case .blank:
                    Spacer().frame(height: 8)
                }
            }
        }
        .textSelection(.enabled)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.bold()
        case 2: .title3.bold()
        case 3: .headline
        default: .subheadline.bold()
        }
    }

    @ViewBuilder
    private func renderInline(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.body)
        } else {
            Text(text)
                .font(.body)
        }
    }

    private enum Block {
        case heading(level: Int, content: String)
        case paragraph(content: String)
        case bulletItem(content: String)
        case numberedItem(num: Int, content: String)
        case separator
        case blank
    }

    private func parseBlocks() -> [Block] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [Block] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                blocks.append(.blank)
            } else if trimmed.hasPrefix("###") {
                blocks.append(.heading(level: 3, content: String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.hasPrefix("##") {
                blocks.append(.heading(level: 2, content: String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(.heading(level: 1, content: String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") || trimmed.hasPrefix("___") {
                blocks.append(.separator)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.bulletItem(content: content))
            } else if let match = trimmed.firstMatch(of: /^(\d+)\.\s+(.+)/) {
                let num = Int(match.1) ?? 1
                let content = String(match.2)
                blocks.append(.numberedItem(num: num, content: content))
            } else {
                blocks.append(.paragraph(content: trimmed))
            }
        }

        return blocks
    }
}

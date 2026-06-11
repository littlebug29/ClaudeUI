import SwiftUI

struct MessageBubbleView: View {
    let message: ConversationMessage
    @State private var isExpanded = false

    var body: some View {
        switch message.content {
        case .text(let text):
            textBubble(text: text, isUser: message.role == .user)
        case .thinking(let text):
            thinkingBubble(text: text)
        case .toolUse(let id, let name, let input):
            toolUseBubble(id: id, name: name, input: input)
        case .toolResult(_, let content, let isError):
            toolResultBubble(content: content, isError: isError)
        }
    }

    @ViewBuilder
    private func textBubble(text: String, isUser: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "You" : "Claude")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                MarkdownTextView(text: text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            }
            .frame(maxWidth: 680, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func thinkingBubble(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "brain")
                .foregroundStyle(.secondary)
                .font(.caption)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("Thinking")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func toolUseBubble(id: String, name: String, input: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: toolIcon(for: name))
                .foregroundStyle(.orange)
                .font(.caption)
                .padding(.top, 2)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Text(input)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(Color.orange.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func toolResultBubble(content: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)
                .font(.caption)
                .padding(.top, 2)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(isError ? "Error" : "Result")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(isError ? .red : .secondary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded && !content.isEmpty {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(30)
                        .padding(10)
                        .background(isError ? Color.red.opacity(0.06) : Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
    }

    private func toolIcon(for name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("bash"): return "terminal"
        case let n where n.contains("read"): return "doc.text"
        case let n where n.contains("write"): return "pencil"
        case let n where n.contains("edit"): return "pencil.and.outline"
        case let n where n.contains("search"), let n where n.contains("grep"): return "magnifyingglass"
        case let n where n.contains("web"): return "globe"
        case let n where n.contains("agent"): return "cpu"
        default: return "wrench"
        }
    }
}

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TypingIndicatorView: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 7, height: 7)
                            .scaleEffect(phase == i ? 1.3 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.4)
                                    .repeatForever()
                                    .delay(Double(i) * 0.15),
                                value: phase
                            )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear { phase = 1 }
    }
}

import SwiftUI
import AppKit

struct ConversationView: View {
    let session: ClaudeSession?
    let project: ClaudeProject?

    @EnvironmentObject private var sessionService: SessionService

    @State private var messages: [ConversationMessage] = []
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            if let session {
                headerBar(session: session)
            }

            if messages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayMessages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }

                            Color.clear.frame(height: 8).id("bottom")
                        }
                        .padding(.top, 8)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: messages.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
            }

            TerminalLauncherView(project: project, session: session)
        }
        .task(id: session?.id) {
            await loadMessages()
        }
    }

    private var displayMessages: [ConversationMessage] {
        messages.filter {
            if case .thinking = $0.content { return false }
            return true
        }
    }

    @ViewBuilder
    private func headerBar(session: ClaudeSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project?.displayName ?? "Unknown Project")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text("Session · \(session.relativeTimeString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    Task { await loadMessages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Reload conversation")

                Button {
                    exportConversation()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Export conversation")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var emptyState: some View {
        Spacer()
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            if session == nil {
                Text("Select a session")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Choose a session from the sidebar\nor start a new one.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No messages yet")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Resume this session in Terminal to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        Spacer()
    }

    private func loadMessages() async {
        guard let session else { messages = []; return }
        messages = await sessionService.loadMessages(for: session)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func exportConversation() {
        let text = messages.map { msg -> String in
            let role = msg.role == .user ? "You" : "Claude"
            switch msg.content {
            case .text(let t): return "**\(role):**\n\(t)"
            case .thinking(let t): return "*[Thinking: \(t.prefix(100))...]*"
            case .toolUse(_, let name, _): return "*[Tool: \(name)]*"
            case .toolResult(_, let c, _): return "*[Result: \(c.prefix(200))...]*"
            }
        }.joined(separator: "\n\n---\n\n")

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "conversation.md"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

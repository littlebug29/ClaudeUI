import SwiftUI

struct RenameSessionSheet: View {
    let session: ClaudeSession
    let currentName: String
    let onSave: (String) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionService: SessionService

    @State private var draftName: String
    @State private var isSuggesting = false
    @State private var suggestionError: String?
    @State private var messages: [ConversationMessage] = []

    private let suggester = SessionNameSuggester()

    init(session: ClaudeSession, currentName: String, onSave: @escaping (String) -> Void, onClear: @escaping () -> Void) {
        self.session = session
        self.currentName = currentName
        self.onSave = onSave
        self.onClear = onClear
        _draftName = State(initialValue: currentName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rename Session")
                        .font(.system(size: 15, weight: .semibold))
                    Text(session.relativeTimeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Session name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Enter a name…", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .onSubmit { saveAndDismiss() }
            }

            // AI suggest button
            HStack(spacing: 10) {
                Button {
                    Task { await suggestName() }
                } label: {
                    HStack(spacing: 6) {
                        if isSuggesting {
                            ProgressView().scaleEffect(0.65).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                        }
                        Text(isSuggesting ? "Asking Claude…" : "Suggest with AI")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSuggesting)

                if !currentName.isEmpty {
                    Spacer()
                    Button("Clear custom name") {
                        onClear()
                        dismiss()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
            }

            // Error banner
            if let error = suggestionError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.orange.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { saveAndDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440, height: 320)
        .task { messages = await sessionService.loadMessages(for: session) }
    }

    private func saveAndDismiss() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }

    private func suggestName() async {
        isSuggesting = true
        suggestionError = nil
        do {
            let name = try await suggester.suggest(from: messages)
            draftName = name
        } catch {
            suggestionError = error.localizedDescription
        }
        isSuggesting = false
    }
}

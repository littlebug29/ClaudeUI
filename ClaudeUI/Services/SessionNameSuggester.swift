import Foundation

/// Asks Claude (via `claude -p`) to suggest a concise session title from
/// the conversation history. Returns a trimmed one-line name.
struct SessionNameSuggester {
    enum SuggestionError: LocalizedError {
        case emptyResponse
        case claudeFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyResponse: return "Claude returned an empty response."
            case .claudeFailed(let msg): return "Claude failed: \(msg)"
            }
        }
    }

    private let cli = ClaudeCLI()

    func suggest(from messages: [ConversationMessage]) async throws -> String {
        let excerpt = buildExcerpt(from: messages)
        guard !excerpt.isEmpty else { throw SuggestionError.emptyResponse }

        let prompt = """
        Based on the following excerpts from a coding session, suggest a concise \
        3-to-6-word title that describes the main task. \
        Reply with ONLY the title — no quotes, no punctuation at the end, no explanation.

        \(excerpt)
        """

        let output = try await cli.runWithStdin(args: ["-p", "--output-format", "text"], input: prompt)

        // claude may exit non-zero on auth issues; surface the error.
        if output.exitCode != 0 {
            let msg = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SuggestionError.claudeFailed(msg.isEmpty ? "exit \(output.exitCode)" : msg)
        }

        // Take the first non-empty line of stdout as the name.
        let name = output.stdout
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""

        guard !name.isEmpty else { throw SuggestionError.emptyResponse }
        // Strip surrounding quotes Claude sometimes adds despite instructions.
        return name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
    }

    // MARK: - Private

    private func buildExcerpt(from messages: [ConversationMessage]) -> String {
        messages
            .filter { if case .thinking = $0.content { return false }; return true }
            .prefix(12)
            .compactMap { msg -> String? in
                let role = msg.role == .user ? "User" : "Claude"
                switch msg.content {
                case .text(let t):
                    let snippet = t.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)
                    return "\(role): \(snippet)"
                case .toolUse(_, let name, _):
                    return "Claude: [ran \(name)]"
                case .toolResult(_, let c, _):
                    let snippet = c.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)
                    return snippet.isEmpty ? nil : "Result: \(snippet)"
                case .thinking:
                    return nil
                }
            }
            .joined(separator: "\n")
    }
}

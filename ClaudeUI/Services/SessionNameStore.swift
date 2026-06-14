import Foundation

/// Persists user-defined session names to ~/.claude/.session-names.json.
/// Keyed by session UUID; absent entries fall back to firstUserPrompt.
@MainActor
final class SessionNameStore: ObservableObject {
    @Published private(set) var names: [String: String] = [:]

    private let storeURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/.session-names.json")

    init() { load() }

    func name(for sessionId: String) -> String? {
        names[sessionId]
    }

    func setName(_ name: String, for sessionId: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            names.removeValue(forKey: sessionId)
        } else {
            names[sessionId] = trimmed
        }
        save()
    }

    func removeName(for sessionId: String) {
        names.removeValue(forKey: sessionId)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        names = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(names) else { return }
        // Write atomically so a crash during save never corrupts the file.
        try? data.write(to: storeURL, options: .atomic)
    }
}

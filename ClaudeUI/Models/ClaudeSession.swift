import Foundation

struct ClaudeSession: Identifiable, Hashable {
    let id: String
    let projectSlug: String
    let filePath: URL
    var firstUserPrompt: String
    var createdAt: Date
    var lastModifiedAt: Date
    var messageCount: Int

    static func == (lhs: ClaudeSession, rhs: ClaudeSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastModifiedAt, relativeTo: Date())
    }
}

extension ClaudeSession {
    static func load(from url: URL, projectSlug: String) -> ClaudeSession? {
        let sessionId = url.deletingPathExtension().lastPathComponent
        guard !sessionId.isEmpty,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date else {
            return nil
        }

        var firstPrompt = ""
        var createdAt = modified
        var count = 0

        if let handle = try? FileHandle(forReadingFrom: url) {
            let data = handle.readDataToEndOfFile()
            handle.closeFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            let lines = text.components(separatedBy: "\n")
            for line in lines {
                guard !line.isEmpty,
                      let lineData = line.data(using: .utf8),
                      let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                    continue
                }
                let type = entry["type"] as? String ?? ""
                if type == "user" || type == "assistant" {
                    count += 1
                }
                if type == "user" && firstPrompt.isEmpty {
                    if let ts = entry["timestamp"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        createdAt = formatter.date(from: ts) ?? modified
                    }
                    if let msg = entry["message"] as? [String: Any],
                       let content = msg["content"] as? [[String: Any]] {
                        for block in content {
                            if block["type"] as? String == "text",
                               let text = block["text"] as? String, !text.isEmpty {
                                firstPrompt = text
                                break
                            }
                        }
                    }
                }
                if !firstPrompt.isEmpty && count > 1 { break }
            }
        }

        return ClaudeSession(
            id: sessionId,
            projectSlug: projectSlug,
            filePath: url,
            firstUserPrompt: firstPrompt.isEmpty ? "Empty session" : firstPrompt,
            createdAt: createdAt,
            lastModifiedAt: modified,
            messageCount: count
        )
    }
}

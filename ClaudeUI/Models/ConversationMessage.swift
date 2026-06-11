import Foundation

enum MessageRole {
    case user
    case assistant
    case tool
    case system
}

enum MessageContent {
    case text(String)
    case thinking(String)
    case toolUse(id: String, name: String, input: String)
    case toolResult(toolUseId: String, content: String, isError: Bool)
}

struct ConversationMessage: Identifiable {
    let id: String
    let role: MessageRole
    let content: MessageContent
    let timestamp: Date
    let uuid: String
    let parentUuid: String?

    var textPreview: String {
        switch content {
        case .text(let s): return s
        case .thinking(let s): return s
        case .toolUse(_, let name, _): return "Tool: \(name)"
        case .toolResult(_, let s, _): return s
        }
    }
}

extension ConversationMessage {
    static func parse(from entry: [String: Any]) -> [ConversationMessage] {
        guard let type = entry["type"] as? String,
              (type == "user" || type == "assistant"),
              let messageDict = entry["message"] as? [String: Any],
              let contentArray = messageDict["content"] as? [[String: Any]] else {
            return []
        }

        let uuid = entry["uuid"] as? String ?? UUID().uuidString
        let parentUuid = entry["parentUuid"] as? String
        let timestamp = parseTimestamp(entry["timestamp"] as? String)

        var messages: [ConversationMessage] = []

        for (i, block) in contentArray.enumerated() {
            guard let blockType = block["type"] as? String else { continue }
            let blockId = "\(uuid)-\(i)"

            switch blockType {
            case "text":
                guard let text = block["text"] as? String, !text.isEmpty else { continue }
                let role: MessageRole = type == "user" ? .user : .assistant
                messages.append(ConversationMessage(
                    id: blockId, role: role, content: .text(text),
                    timestamp: timestamp, uuid: uuid, parentUuid: parentUuid
                ))

            case "thinking":
                guard let text = block["thinking"] as? String, !text.isEmpty else { continue }
                messages.append(ConversationMessage(
                    id: blockId, role: .assistant, content: .thinking(text),
                    timestamp: timestamp, uuid: uuid, parentUuid: parentUuid
                ))

            case "tool_use":
                guard let toolId = block["id"] as? String,
                      let name = block["name"] as? String else { continue }
                let inputDict = block["input"] as? [String: Any] ?? [:]
                let inputStr = (try? JSONSerialization.data(withJSONObject: inputDict, options: [.prettyPrinted]))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                messages.append(ConversationMessage(
                    id: blockId, role: .assistant, content: .toolUse(id: toolId, name: name, input: inputStr),
                    timestamp: timestamp, uuid: uuid, parentUuid: parentUuid
                ))

            case "tool_result":
                guard let toolUseId = block["tool_use_id"] as? String else { continue }
                let inner = block["content"] as? [[String: Any]] ?? []
                let text = inner.compactMap { $0["text"] as? String }.joined(separator: "\n")
                let isError = block["is_error"] as? Bool ?? false
                messages.append(ConversationMessage(
                    id: blockId, role: .user, content: .toolResult(toolUseId: toolUseId, content: text, isError: isError),
                    timestamp: timestamp, uuid: uuid, parentUuid: parentUuid
                ))

            default:
                break
            }
        }

        return messages
    }

    private static func parseTimestamp(_ string: String?) -> Date {
        guard let string else { return Date() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? Date()
    }
}

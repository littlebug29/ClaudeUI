import Foundation

enum StreamEvent {
    case sessionInit(sessionId: String, model: String)
    case textDelta(String)
    case toolUse(id: String, name: String, input: String)
    case toolResult(toolUseId: String, content: String)
    case done(sessionId: String, costUsd: Double, durationMs: Int)
    case error(String)
}

struct StreamParser {
    static func parse(line: String) -> StreamEvent? {
        guard !line.isEmpty,
              let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let type = obj["type"] as? String ?? ""

        switch type {
        case "system":
            let subtype = obj["subtype"] as? String ?? ""
            if subtype == "init" {
                let sessionId = obj["session_id"] as? String ?? ""
                let model = obj["model"] as? String ?? ""
                return .sessionInit(sessionId: sessionId, model: model)
            }
            return nil

        case "assistant":
            guard let message = obj["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { return nil }
            // Return first text block found
            for block in content {
                let blockType = block["type"] as? String ?? ""
                if blockType == "text", let text = block["text"] as? String, !text.isEmpty {
                    return .textDelta(text)
                }
                if blockType == "tool_use",
                   let toolId = block["id"] as? String,
                   let name = block["name"] as? String {
                    let input = block["input"] as? [String: Any] ?? [:]
                    let inputStr = (try? JSONSerialization.data(withJSONObject: input, options: [.prettyPrinted]))
                        .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    return .toolUse(id: toolId, name: name, input: inputStr)
                }
            }
            return nil

        case "tool_result":
            let toolUseId = obj["tool_use_id"] as? String ?? ""
            let contentArr = obj["content"] as? [[String: Any]] ?? []
            let text = contentArr.compactMap { $0["text"] as? String }.joined(separator: "\n")
            return .toolResult(toolUseId: toolUseId, content: text)

        case "result":
            let sessionId = obj["session_id"] as? String ?? ""
            let costUsd = obj["cost_usd"] as? Double ?? 0
            let durationMs = obj["duration_ms"] as? Int ?? 0
            let isError = obj["is_error"] as? Bool ?? false
            if isError {
                let msg = obj["error"] as? String ?? "Unknown error"
                return .error(msg)
            }
            return .done(sessionId: sessionId, costUsd: costUsd, durationMs: durationMs)

        default:
            return nil
        }
    }
}

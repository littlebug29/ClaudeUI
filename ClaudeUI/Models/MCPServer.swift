import Foundation

/// A configured MCP server. Note: we deliberately store only the *names* of
/// env vars and headers, never their secret values.
struct MCPServer: Identifiable, Hashable {
    enum Transport: String, Hashable {
        case stdio
        case http
        case sse
        case unknown
    }

    enum Status: Hashable {
        case connected
        case needsAuth
        case failed
        case pending      // unapproved .mcp.json server
        case unknown

        var label: String {
            switch self {
            case .connected: return "Connected"
            case .needsAuth: return "Needs authentication"
            case .failed: return "Failed to connect"
            case .pending: return "Pending approval"
            case .unknown: return "Unknown"
            }
        }
    }

    var id: String { name }
    let name: String
    let transport: Transport
    let url: String?
    let command: String?
    let args: [String]
    let envKeys: [String]
    let headerKeys: [String]
    let status: Status

    /// Whether this server originates from a plugin (name like `plugin:<p>:<srv>`).
    var isPluginProvided: Bool { name.hasPrefix("plugin:") }
}

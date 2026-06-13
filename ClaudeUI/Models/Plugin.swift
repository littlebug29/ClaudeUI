import Foundation

/// A Claude Code marketplace (source of installable plugins).
struct Marketplace: Identifiable, Hashable, Decodable {
    var id: String { name }
    let name: String
    let source: String          // "github", "git", "local", …
    let repo: String?           // owner/repo for github sources
    let installLocation: String?

    var isOfficial: Bool { name == "claude-plugins-official" }

    var displaySource: String {
        if let repo { return repo }
        return installLocation ?? source
    }
}

/// Unified plugin model used by the UI, merged from the `installed` and
/// `available` arrays of `claude plugin list --available --json`.
struct Plugin: Identifiable, Hashable {
    /// `name@marketplace`.
    let id: String
    let name: String
    let marketplace: String
    let description: String?
    let version: String?
    let scope: String?
    let installed: Bool
    let enabled: Bool
    let installPath: String?
    let installCount: Int?
    let sourceURL: String?       // upstream git url for available plugins

    // Populated from on-disk inspection (set by PluginService).
    var bundledMCPServerNames: [String] = []
    var hasHooks: Bool = false
    var skillNames: [String] = []

    var displayName: String {
        name.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

// MARK: - Raw decoding of `claude plugin list --available --json`

struct PluginCatalog: Decodable {
    let installed: [InstalledEntry]
    let available: [AvailableEntry]

    struct InstalledEntry: Decodable {
        let id: String
        let version: String?
        let scope: String?
        let enabled: Bool
        let installPath: String?
        let installedAt: String?
        let lastUpdated: String?
        let mcpServers: [String: MCPServerDef]?

        struct MCPServerDef: Decodable {
            let type: String?
            let url: String?
        }
    }

    struct AvailableEntry: Decodable {
        let pluginId: String
        let name: String
        let description: String?
        let marketplaceName: String
        let source: Source?
        let installCount: Int?

        struct Source: Decodable {
            let source: String?
            let url: String?
        }
    }
}

extension Plugin {
    /// Splits a `name@marketplace` id into its parts.
    static func splitId(_ id: String) -> (name: String, marketplace: String) {
        guard let at = id.lastIndex(of: "@") else { return (id, "") }
        return (String(id[..<at]), String(id[id.index(after: at)...]))
    }
}

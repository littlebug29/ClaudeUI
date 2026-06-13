import Foundation

/// A skill discoverable by Claude Code, from a plugin or the personal
/// `~/.claude/skills/` directory.
struct Skill: Identifiable, Hashable {
    enum Source: Hashable {
        case plugin(String)     // owning plugin id (name@marketplace)
        case personal
        case builtin

        var label: String {
            switch self {
            case .plugin(let id): return "Plugin · \(Plugin.splitId(id).name)"
            case .personal: return "Personal"
            case .builtin: return "Built-in"
            }
        }
    }

    var id: String { path }
    let name: String
    let description: String
    let source: Source
    let path: String            // absolute path to the skill's directory
    let allowedTools: [String]
    let hasScripts: Bool        // bundles executable files beside SKILL.md
    let autoInvokable: Bool     // disable-model-invocation: false

    /// The owning plugin id, when this is a plugin-provided skill.
    var owningPluginId: String? {
        if case .plugin(let id) = source { return id }
        return nil
    }
}

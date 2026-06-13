import Foundation
import Combine

@MainActor
final class PluginService: ObservableObject {
    @Published var plugins: [Plugin] = []
    @Published var marketplaces: [Marketplace] = []
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var busyPluginIds: Set<String> = []

    private let cli = ClaudeCLI()

    func load() async {
        isLoading = true
        lastError = nil
        do {
            async let catalogTask = cli.runJSON(PluginCatalog.self, ["plugin", "list", "--available", "--json"])
            async let marketsTask = cli.runJSON([Marketplace].self, ["plugin", "marketplace", "list", "--json"])
            let (catalog, markets) = try await (catalogTask, marketsTask)
            marketplaces = markets
            plugins = Self.merge(catalog)
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    var officialMarketplaceNames: Set<String> {
        Set(marketplaces.filter(\.isOfficial).map(\.name))
    }

    func isOfficial(_ plugin: Plugin) -> Bool {
        plugin.marketplace == "claude-plugins-official" || officialMarketplaceNames.contains(plugin.marketplace)
    }

    // MARK: - Mutations (silent; reload on completion)

    func setEnabled(_ plugin: Plugin, enabled: Bool) async {
        await run(plugin.id, ["plugin", enabled ? "enable" : "disable", plugin.id])
    }

    func install(_ plugin: Plugin) async {
        await run(plugin.id, ["plugin", "install", plugin.id, "-s", "user"])
    }

    func uninstall(_ plugin: Plugin) async {
        await run(plugin.id, ["plugin", "uninstall", plugin.id])
    }

    func update(_ plugin: Plugin) async {
        await run(plugin.id, ["plugin", "update", plugin.id])
    }

    func addMarketplace(_ source: String) async {
        do {
            try await cli.runChecked(["plugin", "marketplace", "add", source])
            await load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeMarketplace(_ name: String) async {
        do {
            try await cli.runChecked(["plugin", "marketplace", "remove", name])
            await load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func run(_ pluginId: String, _ args: [String]) async {
        busyPluginIds.insert(pluginId)
        defer { busyPluginIds.remove(pluginId) }
        do {
            try await cli.runChecked(args)
            await load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Merge + on-disk inspection

    nonisolated static func merge(_ catalog: PluginCatalog) -> [Plugin] {
        var byId: [String: Plugin] = [:]

        for entry in catalog.installed {
            let parts = Plugin.splitId(entry.id)
            var plugin = Plugin(
                id: entry.id, name: parts.name, marketplace: parts.marketplace,
                description: nil, version: entry.version, scope: entry.scope,
                installed: true, enabled: entry.enabled, installPath: entry.installPath,
                installCount: nil, sourceURL: nil
            )
            plugin.bundledMCPServerNames = Array(entry.mcpServers?.keys ?? [:].keys).sorted()
            if let path = entry.installPath {
                inspectOnDisk(path: path, into: &plugin)
            }
            byId[entry.id] = plugin
        }

        for entry in catalog.available {
            let parts = Plugin.splitId(entry.pluginId)
            if var existing = byId[entry.pluginId] {
                // Available metadata enriches an already-installed plugin.
                existing = Plugin(
                    id: existing.id, name: existing.name, marketplace: existing.marketplace,
                    description: entry.description ?? existing.description,
                    version: existing.version, scope: existing.scope, installed: true,
                    enabled: existing.enabled, installPath: existing.installPath,
                    installCount: entry.installCount, sourceURL: entry.source?.url
                ).withInspection(from: existing)
                byId[entry.pluginId] = existing
            } else {
                byId[entry.pluginId] = Plugin(
                    id: entry.pluginId, name: parts.name.isEmpty ? entry.name : parts.name,
                    marketplace: entry.marketplaceName, description: entry.description,
                    version: nil, scope: nil, installed: false, enabled: false,
                    installPath: nil, installCount: entry.installCount, sourceURL: entry.source?.url
                )
            }
        }

        return byId.values.sorted {
            if $0.installed != $1.installed { return $0.installed && !$1.installed }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Reads hooks / bundled MCP / skills directly from a plugin's install path.
    nonisolated static func inspectOnDisk(path: String, into plugin: inout Plugin) {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: path)

        plugin.hasHooks = fm.fileExists(atPath: root.appendingPathComponent("hooks/hooks.json").path)

        let mcpURL = root.appendingPathComponent(".mcp.json")
        if plugin.bundledMCPServerNames.isEmpty,
           let data = try? Data(contentsOf: mcpURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let servers = obj["mcpServers"] as? [String: Any] {
            plugin.bundledMCPServerNames = servers.keys.sorted()
        }

        let skillsURL = root.appendingPathComponent("skills")
        if let entries = try? fm.contentsOfDirectory(at: skillsURL, includingPropertiesForKeys: [.isDirectoryKey]) {
            plugin.skillNames = entries.compactMap { entry in
                let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return isDir ? entry.lastPathComponent : nil
            }.sorted()
        }
    }
}

private extension Plugin {
    /// Carries inspected on-disk fields onto a rebuilt copy.
    func withInspection(from other: Plugin) -> Plugin {
        var copy = self
        copy.bundledMCPServerNames = other.bundledMCPServerNames
        copy.hasHooks = other.hasHooks
        copy.skillNames = other.skillNames
        return copy
    }
}

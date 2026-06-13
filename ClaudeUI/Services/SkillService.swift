import Foundation
import Combine

@MainActor
final class SkillService: ObservableObject {
    @Published var skills: [Skill] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let cli = ClaudeCLI()

    nonisolated private static var homeURL: URL { FileManager.default.homeDirectoryForCurrentUser }
    nonisolated private static var personalSkillsURL: URL { homeURL.appendingPathComponent(".claude/skills") }
    nonisolated private static var pluginCacheURL: URL { homeURL.appendingPathComponent(".claude/plugins/cache") }

    func load() async {
        isLoading = true
        skills = await Task.detached(priority: .userInitiated) {
            Self.discover()
        }.value
        isLoading = false
    }

    /// Scaffolds a new personal skill via `claude plugin init`, then reloads.
    func createPersonalSkill(named name: String) async {
        do {
            try await cli.runChecked(["plugin", "init", name])
            await load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Discovery

    nonisolated static func discover() -> [Skill] {
        var found: [Skill] = []
        found.append(contentsOf: personalSkills())
        found.append(contentsOf: pluginSkills())

        // Dedupe plugin skills across cached versions, keeping the highest version.
        var best: [String: Skill] = [:]
        for skill in found {
            let key = "\(skill.source.label)/\(skill.name)"
            best[key] = skill   // pluginSkills() already yields ascending version order
        }
        return best.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func personalSkills() -> [Skill] {
        skillDirs(in: personalSkillsURL).compactMap { dir in
            parseSkill(at: dir, source: .personal)
        }
    }

    nonisolated private static func pluginSkills() -> [Skill] {
        let fm = FileManager.default
        guard let marketplaces = try? fm.contentsOfDirectory(at: pluginCacheURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var result: [Skill] = []
        for marketplace in marketplaces {
            let plugins = (try? fm.contentsOfDirectory(at: marketplace, includingPropertiesForKeys: nil)) ?? []
            for pluginDir in plugins {
                let versions = ((try? fm.contentsOfDirectory(at: pluginDir, includingPropertiesForKeys: nil)) ?? [])
                    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                for versionDir in versions {
                    let pluginId = "\(pluginDir.lastPathComponent)@\(marketplace.lastPathComponent)"
                    let skillsDir = versionDir.appendingPathComponent("skills")
                    for dir in skillDirs(in: skillsDir) {
                        if let skill = parseSkill(at: dir, source: .plugin(pluginId)) {
                            result.append(skill)
                        }
                    }
                }
            }
        }
        return result
    }

    nonisolated private static func skillDirs(in parent: URL) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        return entries.filter { entry in
            (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true &&
            fm.fileExists(atPath: entry.appendingPathComponent("SKILL.md").path)
        }
    }

    nonisolated private static func parseSkill(at dir: URL, source: Skill.Source) -> Skill? {
        let skillFile = dir.appendingPathComponent("SKILL.md")
        guard let text = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }
        let fm = parseFrontmatter(text)

        let name = fm["name"] ?? dir.lastPathComponent
        let description = fm["description"] ?? ""
        let allowedTools = (fm["allowed-tools"] ?? fm["allowedTools"]).map(parseList) ?? []
        let disableInvocation = (fm["disable-model-invocation"] ?? "false").lowercased() == "true"

        return Skill(
            name: name,
            description: description,
            source: source,
            path: dir.path,
            allowedTools: allowedTools,
            hasScripts: dirContainsScripts(dir),
            autoInvokable: !disableInvocation
        )
    }

    /// Minimal YAML-frontmatter reader: the `---` block at the top, flat `key: value`.
    nonisolated static func parseFrontmatter(_ text: String) -> [String: String] {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [:] }
        var result: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")),
               value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            if !key.isEmpty { result[key] = value }
        }
        return result
    }

    /// Parses an `allowed-tools` value that may be `[A, B]` or `A, B`.
    nonisolated private static func parseList(_ value: String) -> [String] {
        var v = value
        if v.hasPrefix("[") && v.hasSuffix("]") { v = String(v.dropFirst().dropLast()) }
        return v.split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"'")) }
            .filter { !$0.isEmpty }
    }

    nonisolated private static func dirContainsScripts(_ dir: URL) -> Bool {
        let fm = FileManager.default
        let scriptExts: Set<String> = ["sh", "py", "js", "ts", "rb", "pl", "bash", "zsh"]
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isExecutableKey],
                                             options: [.skipsHiddenFiles]) else { return false }
        for case let url as URL in enumerator {
            if url.lastPathComponent == "SKILL.md" { continue }
            if scriptExts.contains(url.pathExtension.lowercased()) { return true }
            if (try? url.resourceValues(forKeys: [.isExecutableKey]).isExecutable) == true,
               (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                return true
            }
        }
        return false
    }
}

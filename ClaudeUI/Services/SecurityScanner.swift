import Foundation

/// Offline heuristic security checks for MCP servers, plugins and skills.
/// Pure functions — no network, no side effects — so they're trivially testable.
enum SecurityScanner {

    // Hosts considered first-party / trusted for remote MCP endpoints.
    private static let trustedHostSuffixes = [
        "anthropic.com", "claude.ai", "githubcopilot.com", "github.com",
    ]

    // stdio commands that fetch-and-execute remote code at launch.
    private static let fetchExecRunners = ["npx", "uvx", "bunx", "pnpx", "dlx"]

    private static let secretKeyHints = ["token", "key", "secret", "authorization", "auth", "password", "credential"]

    // MARK: - MCP

    static func scan(mcp server: MCPServer) -> SecurityReport {
        var findings: [SecurityFinding] = []

        if server.status == .pending {
            findings.append(SecurityFinding(
                severity: .info,
                title: "Pending approval",
                detail: "Defined in a project .mcp.json file and not yet approved. Claude Code will ask before connecting."
            ))
        }

        switch server.transport {
        case .http, .sse:
            if let url = server.url, let host = URL(string: url)?.host {
                let trusted = trustedHostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }
                if !trusted {
                    findings.append(SecurityFinding(
                        severity: .warning,
                        title: "Connects to a third-party server",
                        detail: "Tool calls and their data are sent to \(host). Only add servers you trust with your project context."
                    ))
                }
            }
        case .stdio:
            if let command = server.command {
                let base = (command as NSString).lastPathComponent
                if fetchExecRunners.contains(base) {
                    findings.append(SecurityFinding(
                        severity: .critical,
                        title: "Runs remote code on launch",
                        detail: "Uses `\(base)` to download and execute a package every time it starts. Pin a version and verify the package author before trusting it."
                    ))
                } else {
                    findings.append(SecurityFinding(
                        severity: .info,
                        title: "Runs a local command",
                        detail: "Launches `\(command)` on your machine with your permissions."
                    ))
                }
            }
        case .unknown:
            break
        }

        let secretNames = (server.envKeys + server.headerKeys).filter { name in
            let lower = name.lowercased()
            return secretKeyHints.contains { lower.contains($0) }
        }
        if !secretNames.isEmpty {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Requires a secret",
                detail: "Expects credentials: \(secretNames.joined(separator: ", ")). Make sure you provide these only to a server you trust."
            ))
        }

        return SecurityReport(findings: findings)
    }

    // MARK: - Plugin

    /// `marketplaceIsOfficial` lets the caller pass trust info it already knows.
    static func scan(plugin: Plugin, marketplaceIsOfficial: Bool) -> SecurityReport {
        var findings: [SecurityFinding] = []

        if plugin.hasHooks {
            findings.append(SecurityFinding(
                severity: .critical,
                title: "Runs lifecycle hooks",
                detail: "Bundles hook scripts that Claude Code executes automatically (e.g. on session start, prompt submit, or after tool use). Review hooks/hooks.json before enabling."
            ))
        }

        if !plugin.bundledMCPServerNames.isEmpty {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Bundles MCP server(s)",
                detail: "Adds MCP server(s): \(plugin.bundledMCPServerNames.joined(separator: ", ")). These can send your data to remote endpoints or run local commands."
            ))
        }

        if !marketplaceIsOfficial {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Third-party marketplace",
                detail: "From \(plugin.marketplace), not the official Anthropic marketplace. Verify the source repository before installing."
            ))
        }

        if findings.isEmpty {
            findings.append(SecurityFinding(
                severity: .info,
                title: "No automated execution detected",
                detail: "Provides commands/skills only — no bundled hooks or MCP servers found."
            ))
        }

        return SecurityReport(findings: findings)
    }

    // MARK: - Skill

    static func scan(skill: Skill) -> SecurityReport {
        var findings: [SecurityFinding] = []

        let powerfulTools = ["Bash", "Write", "Edit", "MultiEdit", "NotebookEdit"]
        let granted = skill.allowedTools.filter { tool in
            powerfulTools.contains { tool == $0 || tool.hasPrefix($0 + "(") }
        }
        if !granted.isEmpty {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Can modify your system",
                detail: "Requests tools that run commands or write files: \(granted.joined(separator: ", "))."
            ))
        }

        if skill.hasScripts {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Bundles executable scripts",
                detail: "Ships scripts alongside SKILL.md that may be run when the skill is used. Review them before trusting."
            ))
        }

        if skill.autoInvokable {
            findings.append(SecurityFinding(
                severity: .info,
                title: "Can self-invoke",
                detail: "Claude may invoke this skill automatically when it judges it relevant (disable-model-invocation is not set)."
            ))
        }

        return SecurityReport(findings: findings)
    }
}

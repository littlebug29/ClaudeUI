import Testing
@testable import ClaudeUI

struct SecurityScannerTests {

    // MARK: MCP

    @Test func remoteThirdPartyServerWarns() {
        let server = MCPServer(name: "acme", transport: .http, url: "https://acme.dev/mcp",
                               command: nil, args: [], envKeys: [], headerKeys: [], status: .connected)
        let report = SecurityScanner.scan(mcp: server)
        #expect(report.worstSeverity == .warning)
        #expect(report.findings.contains { $0.title.contains("third-party") })
    }

    @Test func trustedHostDoesNotWarn() {
        let server = MCPServer(name: "drive", transport: .http, url: "https://drivemcp.googleapis.com/mcp",
                               command: nil, args: [], envKeys: [], headerKeys: [], status: .connected)
        // googleapis is not in the trust list, but anthropic/github are; assert the rule by host.
        let trusted = MCPServer(name: "gh", transport: .http, url: "https://api.githubcopilot.com/mcp/",
                                command: nil, args: [], envKeys: [], headerKeys: [], status: .connected)
        #expect(SecurityScanner.scan(mcp: trusted).findings.allSatisfy { !$0.title.contains("third-party") })
        #expect(SecurityScanner.scan(mcp: server).worstSeverity == .warning)
    }

    @Test func npxStdioIsCritical() {
        let server = MCPServer(name: "x", transport: .stdio, url: nil, command: "npx",
                               args: ["-y", "some-pkg"], envKeys: [], headerKeys: [], status: .connected)
        let report = SecurityScanner.scan(mcp: server)
        #expect(report.worstSeverity == .critical)
    }

    @Test func secretBearingHeadersWarn() {
        let server = MCPServer(name: "x", transport: .http, url: "https://api.githubcopilot.com/mcp/",
                               command: nil, args: [], envKeys: [], headerKeys: ["Authorization"], status: .connected)
        #expect(SecurityScanner.scan(mcp: server).findings.contains { $0.title.contains("secret") })
    }

    // MARK: Plugin

    @Test func pluginWithHooksIsCritical() {
        var plugin = makePlugin()
        plugin.hasHooks = true
        let report = SecurityScanner.scan(plugin: plugin, marketplaceIsOfficial: true)
        #expect(report.worstSeverity == .critical)
    }

    @Test func bundledMCPWarns() {
        var plugin = makePlugin()
        plugin.bundledMCPServerNames = ["figma"]
        let report = SecurityScanner.scan(plugin: plugin, marketplaceIsOfficial: true)
        #expect(report.worstSeverity == .warning)
    }

    @Test func thirdPartyMarketplaceWarns() {
        let plugin = makePlugin(marketplace: "some-community")
        let report = SecurityScanner.scan(plugin: plugin, marketplaceIsOfficial: false)
        #expect(report.findings.contains { $0.title.contains("Third-party marketplace") })
    }

    @Test func cleanPluginIsInfo() {
        let report = SecurityScanner.scan(plugin: makePlugin(), marketplaceIsOfficial: true)
        #expect(report.worstSeverity == .info)
    }

    // MARK: Skill

    @Test func skillWithBashWarns() {
        let skill = Skill(name: "s", description: "", source: .personal, path: "/tmp/s",
                          allowedTools: ["Bash(git:*)", "Read"], hasScripts: false, autoInvokable: false)
        #expect(SecurityScanner.scan(skill: skill).worstSeverity == .warning)
    }

    @Test func skillWithScriptsWarns() {
        let skill = Skill(name: "s", description: "", source: .personal, path: "/tmp/s",
                          allowedTools: [], hasScripts: true, autoInvokable: false)
        #expect(SecurityScanner.scan(skill: skill).worstSeverity == .warning)
    }

    private func makePlugin(marketplace: String = "claude-plugins-official") -> Plugin {
        Plugin(id: "p@\(marketplace)", name: "p", marketplace: marketplace, description: nil,
               version: "1.0.0", scope: "user", installed: true, enabled: true,
               installPath: "/tmp/p", installCount: nil, sourceURL: nil)
    }
}

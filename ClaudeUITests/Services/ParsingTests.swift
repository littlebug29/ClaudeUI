import Testing
import Foundation
@testable import ClaudeUI

struct ParsingTests {

    @Test func decodesAndMergesCatalog() throws {
        let json = """
        {
          "installed": [
            { "id": "figma@claude-plugins-official", "version": "2.2.50", "scope": "user",
              "enabled": true, "installPath": "/tmp/figma",
              "mcpServers": { "figma": { "type": "http", "url": "https://mcp.figma.com/mcp" } } },
            { "id": "code-review@claude-plugins-official", "version": "unknown", "scope": "user",
              "enabled": false, "installPath": "/tmp/cr" }
          ],
          "available": [
            { "pluginId": "figma@claude-plugins-official", "name": "figma",
              "description": "Figma plugin", "marketplaceName": "claude-plugins-official",
              "source": { "source": "git", "url": "https://github.com/x/y.git" }, "installCount": 99 },
            { "pluginId": "new-tool@claude-plugins-official", "name": "new-tool",
              "description": "Not installed", "marketplaceName": "claude-plugins-official", "installCount": 5 }
          ]
        }
        """
        let catalog = try JSONDecoder().decode(PluginCatalog.self, from: Data(json.utf8))
        let merged = PluginService.merge(catalog)

        #expect(merged.count == 3)
        let figma = try #require(merged.first { $0.id == "figma@claude-plugins-official" })
        #expect(figma.installed)
        #expect(figma.description == "Figma plugin")          // enriched from available
        #expect(figma.bundledMCPServerNames == ["figma"])     // from installed mcpServers
        #expect(figma.installCount == 99)

        let newTool = try #require(merged.first { $0.id == "new-tool@claude-plugins-official" })
        #expect(!newTool.installed)

        // Installed plugins sort ahead of available ones.
        #expect(merged.last?.id == "new-tool@claude-plugins-official")
    }

    @Test func splitIdHandlesAtSign() {
        let parts = Plugin.splitId("commit-commands@claude-plugins-official")
        #expect(parts.name == "commit-commands")
        #expect(parts.marketplace == "claude-plugins-official")
    }

    @Test func parsesMCPListWithColonNames() {
        let text = """
        Checking MCP server health…

        claude.ai Google Drive: https://drivemcp.googleapis.com/mcp/v1 - ! Needs authentication
        plugin:github:github: https://api.githubcopilot.com/mcp/ (HTTP) - ✘ Failed to connect
        plugin:figma:figma: https://mcp.figma.com/mcp (HTTP) - ! Needs authentication
        """
        let servers = MCPService.parseList(text)
        #expect(servers.count == 3)

        let gh = try! #require(servers.first { $0.name == "plugin:github:github" })
        #expect(gh.transport == .http)
        #expect(gh.url == "https://api.githubcopilot.com/mcp/")
        #expect(gh.status == .failed)

        let drive = try! #require(servers.first { $0.name == "claude.ai Google Drive" })
        #expect(drive.status == .needsAuth)
        #expect(drive.url == "https://drivemcp.googleapis.com/mcp/v1")
    }

    @Test func parsesGetEnrichment() {
        let base = MCPServer(name: "x", transport: .stdio, url: nil, command: nil, args: [],
                             envKeys: [], headerKeys: [], status: .connected)
        let text = """
        x:
          Scope: User config
          Type: stdio
          Command: my-server
          Args: --flag arg1
          Environment: API_KEY=secret, REGION=us
        """
        let enriched = MCPService.parseGet(text, fallback: base)
        #expect(enriched.command == "my-server")
        #expect(enriched.args == ["--flag", "arg1"])
        #expect(enriched.envKeys == ["API_KEY", "REGION"])   // names only, no values
    }

    @Test func parsesSkillFrontmatter() {
        let md = """
        ---
        name: my-skill
        description: "Does a thing"
        allowed-tools: Bash, Read
        disable-model-invocation: true
        ---

        # Body
        """
        let fm = SkillService.parseFrontmatter(md)
        #expect(fm["name"] == "my-skill")
        #expect(fm["description"] == "Does a thing")
        #expect(fm["allowed-tools"] == "Bash, Read")
        #expect(fm["disable-model-invocation"] == "true")
    }
}

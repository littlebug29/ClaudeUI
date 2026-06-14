# ClaudeUI

A native macOS app for browsing and resuming Claude Code sessions, and for managing its extensions — MCP servers, plugins, and skills — with a built-in security check. Built for developers who work with Claude Code and need a better way to manage their TUI sessions.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Download

**[ClaudeUI-v1.0.0.dmg](https://github.com/littlebug29/ClaudeUI/releases/tag/v1.0.0)** — macOS 14+

1. Open the DMG and drag **ClaudeUI** to your Applications folder
2. **Right-click → Open** the first time (the app is ad-hoc signed, not notarized — Gatekeeper will otherwise block it)
3. The app lives in your menu bar after launch

## The Problem

When using Claude Code, developers spend most of their time in the terminal TUI. This makes it hard to:

- Browse and search past sessions across multiple projects
- Resume a specific conversation without remembering its ID
- See what happened in a session without scrolling through terminal history
- Quickly switch context between sessions in different projects

## What ClaudeUI Does

ClaudeUI reads the session files that Claude Code writes to `~/.claude/projects/` and surfaces them in a native Mac UI. From the sidebar you can browse every session grouped by project, search by name or content, and click **Resume in Terminal** to pick up exactly where you left off — `claude --resume <sessionId>` runs in a new Terminal window, already `cd`'d into the project directory.

A sidebar mode switcher turns the same window into an **extension manager**: install and inspect MCP servers, browse and install plugins from marketplaces, and review your skills — each annotated with a local security check so you know what an extension can do before you trust it.

## Features

### Sessions
- **Session browser** — all projects and sessions in a searchable sidebar, sorted by recency
- **Conversation viewer** — full message history with tool-use and tool-result blocks
- **One-click resume** — launches Terminal.app with the correct `claude --resume` command
- **Session renaming** — give any session a custom name; right-click → Rename or use the pencil button in the conversation header
- **AI name suggestions** — the Rename sheet can ask `claude -p` to read the conversation and suggest a concise 3-6 word title
- **Menu bar extra** — quick access to the 5 most recent sessions (shows custom names) from any app
- **Live updates** — sidebar refreshes automatically when new sessions are created
- **Export** — save any conversation as Markdown

### Extension manager
- **MCP servers** — list configured servers with live health status, view details, add a server (HTTP/SSE/stdio) and remove one
- **Plugins** — browse installed and available plugins across marketplaces, search, install/uninstall, enable/disable, update, and add marketplaces by GitHub repo or URL
- **Skills** — view skills from plugins and your personal `~/.claude/skills/`, with frontmatter and tool grants; scaffold a new personal skill
- **Security checks** — every MCP server, plugin, and skill gets an offline heuristic scan with a severity badge (third-party endpoints, secret-bearing headers, `npx`/`uvx` fetch-and-exec, lifecycle hooks, bundled MCP servers, Bash/Write tool grants, bundled scripts)

### General
- **Driven by the official CLI** — all changes go through `claude` commands, never hand-edited config files
- **No API key required** — reads local files and drives the local CLI; never calls the Anthropic API directly

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code](https://claude.ai/code) CLI installed (`brew install claude-code` or `npm i -g @anthropic-ai/claude-code`)
- Xcode 15+ (to build from source only)

## Getting Started (from source)

```bash
git clone https://github.com/littlebug29/ClaudeUI.git
cd ClaudeUI
open ClaudeUI.xcodeproj
```

Press **⌘R** in Xcode to run.

> **Note:** ClaudeUI runs without sandbox (`com.apple.security.app-sandbox: false`) so it can read `~/.claude/projects/` and spawn Terminal. This is intentional for a developer tool.

## How It Works

Claude Code stores every session as a JSONL file at:
```
~/.claude/projects/<encoded-project-path>/<session-uuid>.jsonl
```

Each line is a JSON event (`user`, `assistant`, `tool_use`, `tool_result`, etc.). ClaudeUI parses these files directly — no subprocess or API call needed for browsing history.

When you click **Resume in Terminal**, ClaudeUI writes a temporary `.command` script that `cd`s into the project directory and runs `claude --resume <sessionId>`, then opens it with Terminal.app. The terminal window stays interactive after Claude exits.

**Session renaming** persists custom names to `~/.claude/.session-names.json` (a simple `{sessionId: name}` map). The AI suggestion feature calls `claude -p --output-format text` with an excerpt of the conversation and asks for a concise title. The subprocess runs in `/tmp` to avoid triggering macOS permission prompts for protected folders.

For the extension manager, ClaudeUI drives the `claude` CLI rather than editing config files directly. Non-interactive actions run in-process; anything that may need a sign-in or trust prompt is handed off to a Terminal window via the same `.command` mechanism. Security checks are pure local heuristics — they flag common risks but don't guarantee safety.

## Project Structure

```
ClaudeUI/
├── App/
│   └── ClaudeUIApp.swift          # @main, MenuBarExtra, keyboard commands
├── Models/
│   ├── ClaudeProject.swift        # Project grouped from slug directory
│   ├── ClaudeSession.swift        # Session metadata from JSONL header
│   ├── ConversationMessage.swift  # Parsed message types (text, tool, etc.)
│   ├── MCPServer.swift            # MCP server config
│   ├── Plugin.swift               # Plugin + Marketplace + catalog decoding
│   ├── Skill.swift                # Skill from plugin or ~/.claude/skills/
│   └── SecurityReport.swift       # Severity, findings, report
├── Services/
│   ├── SessionService.swift       # Scans ~/.claude/projects/, FS watcher
│   ├── ClaudeProcessManager.swift # claude CLI subprocess wrapper
│   ├── ClaudeCLI.swift            # Central claude CLI runner (run/JSON/stdin/terminal)
│   ├── MCPService.swift           # mcp list/get/add/remove
│   ├── PluginService.swift        # plugin + marketplace commands, disk inspect
│   ├── SkillService.swift         # discovers skills, parses SKILL.md frontmatter
│   ├── SecurityScanner.swift      # offline heuristic security checks
│   ├── SessionNameStore.swift     # persists custom session names to ~/.claude/.session-names.json
│   └── SessionNameSuggester.swift # calls claude -p to generate a session title
├── Helpers/
│   └── StreamParser.swift         # Parses stream-json CLI output
└── Views/
    ├── ContentView.swift          # NavigationSplitView root + mode switcher
    ├── SessionListView.swift      # Sidebar: projects + sessions + rename context menu
    ├── ConversationView.swift     # Message thread + header + rename button
    ├── MessageBubbleView.swift    # Per-message rendering
    ├── TerminalLauncherView.swift # Resume / run-command-in-Terminal launcher
    ├── RenameSessionSheet.swift   # Rename sheet with AI suggestion
    ├── MCP/                       # MCP list, detail, add-server sheet
    ├── Plugins/                   # Plugin browser, detail, add-marketplace sheet
    ├── Skills/                    # Skill list + detail
    └── Security/                  # Shared SecurityBadge + report view
```

## Building a Release

```bash
# Release build (ad-hoc signed)
xcodebuild \
  -project ClaudeUI.xcodeproj \
  -scheme ClaudeUI \
  -configuration Release \
  -derivedDataPath /tmp/ClaudeUI-build \
  CODE_SIGN_IDENTITY="-" \
  build

# Package as DMG
STAGING=$(mktemp -d)
cp -R /tmp/ClaudeUI-build/Build/Products/Release/ClaudeUI.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "ClaudeUI 1.0.0" -srcfolder "$STAGING" -format UDZO ClaudeUI-v1.0.0.dmg
```

## Contributing

Pull requests welcome. Keep the dependency count at zero — the app intentionally uses only Foundation and SwiftUI (no Combine, no third-party packages).

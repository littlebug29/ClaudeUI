# ClaudeUI

A native macOS app for browsing and resuming Claude Code sessions — built for enterprise developers who work with Claude Code through a third-party provider and need a better way to manage their TUI sessions.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## The Problem

When using Claude Code with an enterprise API provider, developers spend most of their time in the terminal TUI. This makes it hard to:

- Browse and search past sessions across multiple projects
- Resume a specific conversation without remembering its ID
- See what happened in a session without scrolling through terminal history
- Quickly switch context between sessions in different projects

## What ClaudeUI Does

ClaudeUI reads the session files that Claude Code writes to `~/.claude/projects/` and surfaces them in a native Mac UI. From the sidebar you can browse every session grouped by project, search by content, and click **Resume in Terminal** to pick up exactly where you left off — `claude --resume <sessionId>` runs in a new Terminal window, already `cd`'d into the project directory.

## Features

- **Session browser** — all projects and sessions in a searchable sidebar, sorted by recency
- **Conversation viewer** — full message history with collapsible tool-use and tool-result blocks
- **One-click resume** — launches Terminal.app with the correct `claude --resume` command
- **Menu bar extra** — quick access to the 5 most recent sessions from any app
- **Live updates** — sidebar refreshes automatically when new sessions are created
- **Export** — save any conversation as Markdown
- **No API key required** — reads local session files only, never calls the Anthropic API directly

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code](https://claude.ai/code) CLI installed (`brew install claude-code` or `npm i -g @anthropic-ai/claude-code`)
- Xcode 15+ (to build from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Getting Started

```bash
git clone https://github.com/littlebug29/ClaudeUI.git
cd ClaudeUI
xcodegen generate
open ClaudeUI.xcodeproj
```

Then press **⌘R** in Xcode to run.

> **Note:** ClaudeUI runs without sandbox (`com.apple.security.app-sandbox: false`) so it can read `~/.claude/projects/` and spawn Terminal. This is intentional for a developer tool.

## How It Works

Claude Code stores every session as a JSONL file at:
```
~/.claude/projects/<encoded-project-path>/<session-uuid>.jsonl
```

Each line is a JSON event (`user`, `assistant`, `tool_use`, `tool_result`, etc.). ClaudeUI parses these files directly — no subprocess or API call needed for browsing history.

When you click **Resume in Terminal**, ClaudeUI writes a temporary `.command` script that `cd`s into the project directory and runs `claude --resume <sessionId>`, then opens it with Terminal.app. The terminal window stays interactive after Claude exits.

## Project Structure

```
ClaudeUI/
├── App/
│   └── ClaudeUIApp.swift          # @main, MenuBarExtra, keyboard commands
├── Models/
│   ├── ClaudeProject.swift        # Project grouped from slug directory
│   ├── ClaudeSession.swift        # Session metadata from JSONL header
│   └── ConversationMessage.swift  # Parsed message types (text, tool, etc.)
├── Services/
│   ├── SessionService.swift       # Scans ~/.claude/projects/, FS watcher
│   └── ClaudeProcessManager.swift # claude CLI subprocess wrapper
├── Helpers/
│   └── StreamParser.swift         # Parses stream-json CLI output
└── Views/
    ├── ContentView.swift          # NavigationSplitView root
    ├── SessionListView.swift      # Sidebar: projects + sessions
    ├── ConversationView.swift     # Message thread + header
    ├── MessageBubbleView.swift    # Per-message rendering
    ├── InputBarView.swift         # Prompt input component
    └── TerminalLauncherView.swift # Resume-in-Terminal bottom bar
```

## Building

```bash
# Generate Xcode project (re-run after editing project.yml)
xcodegen generate

# Build from command line
xcodebuild -scheme ClaudeUI -configuration Debug -destination 'platform=macOS' build
```

## Contributing

Pull requests welcome. Keep the dependency count at zero — the app intentionally relies only on Foundation, SwiftUI, and Combine.

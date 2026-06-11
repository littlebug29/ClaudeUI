# ClaudeUI

A macOS app for browsing and resuming Claude Code sessions. Reads session
history from `~/.claude/projects/` and launches `claude` in a Terminal window
to continue a session in its original project directory.

## Build & Run

Use the `BuildProject` MCP tool (xcode-tools). Don't shell out to `xcodebuild`
for routine builds — the in-IDE build is faster and surfaces errors the same
way Xcode does. After Swift edits, prefer `XcodeRefreshCodeIssuesInFile` for
quick per-file diagnostics before a full build.

Deployment target: macOS. App is **not sandboxed** (`ClaudeUI.entitlements`
sets `com.apple.security.app-sandbox` to `false`) so it can read user home
directories and spawn child processes freely.

## Architecture

SwiftUI + AppKit interop. No Combine — use `async`/`await`.

```
App/ClaudeUIApp.swift          @main, MenuBarExtra, command groups
Models/                        Plain value types (ClaudeProject, ClaudeSession,
                               ConversationMessage)
Services/SessionService.swift  Loads projects/sessions from ~/.claude/projects
Services/ClaudeProcessManager  Detects the `claude` binary path; legacy
                               sendMessage() lives here but is unused by the
                               UI (kept for currentSessionId tracking)
Helpers/StreamParser.swift     Parses claude --output-format stream-json lines
Views/
  ContentView                  NavigationSplitView shell, Settings sheet
  SessionListView              Sidebar of projects → sessions
  ConversationView             Read-only message history viewer
  MessageBubbleView            Per-message rendering + markdown
  TerminalLauncherView         Bottom bar; launches Terminal at the project
                               folder and resumes the selected session
```

### In-app messaging was removed

The original `InputBarView` (text input + send button) was replaced by
`TerminalLauncherView`. Conversations are now **viewed** in-app and
**continued** in Terminal. Don't reintroduce an in-app input bar without
discussing — the design decision is to delegate live interaction to the
official `claude` CLI.

`ClaudeProcessManager.sendMessage(...)` is retained but unused. Its public
`@Published` state (`currentSessionId`, `isProcessing`) is still read by
`MenuBarView` for the active-session indicator dot.

## Launching Terminal — use `.command`, not AppleScript

`TerminalLauncher.launch(...)` writes a temporary `.command` shell script to
`NSTemporaryDirectory()`, marks it executable, and opens it with
`Terminal.app` via `NSWorkspace.open(_:withApplicationAt:configuration:)`.

**Do not switch back to AppleScript / `NSAppleScript` for this.** Driving
Terminal with `do script` requires:
1. `NSAppleEventsUsageDescription` in `Info.plist` (not currently set), and
2. a user-granted entry under System Settings → Privacy & Security → Automation.

Without both, macOS silently denies the Apple event: Terminal opens (because
`activate` doesn't need Apple Events) but the `cd` + `claude --resume` never
runs. The `.command` route uses LaunchServices only — no permission prompts.

The trailing `exec "$SHELL" -l` in the generated script keeps the Terminal
window interactive after `claude` exits.

## Process spawning gotchas

When using `Foundation.Process`:

- **Never use `try?` on `process.run()` if you then call `waitUntilExit()`.**
  A failed `run()` leaves the Process's internal task pointer nil; calling
  `waitUntilExit()` afterwards dereferences it and crashes with
  `EXC_BAD_ACCESS @ 0x0`. Use `do/try` and bail on failure.
- Read pipe output **before** `waitUntilExit()` when the child might produce
  more than a pipe buffer's worth of data (~64KB), otherwise the child blocks
  on write and we block on wait → deadlock.
- GUI apps inherit launchd's minimal `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`),
  which usually doesn't include `/opt/homebrew/bin`. That's why
  `detectClaudePath()` probes well-known absolute paths before falling back to
  `/usr/bin/which claude`.

## Session data model

Sessions live on disk as JSONL at
`~/.claude/projects/<slug>/<session-uuid>.jsonl`. The slug is the project's
absolute path with `/` → `-` (so `/Users/foo/bar` becomes `-Users-foo-bar`).
`ClaudeProject.decodePath(from:)` does a best-effort reverse, but the
authoritative `projectPath` should come from the session file's `cwd` field
when available.

`ClaudeSession.load(from:projectSlug:)` reads the JSONL line-by-line to
extract the first user prompt, message count, and created timestamp. This
runs synchronously inside `SessionService` — keep it off the main thread when
batch-loading many sessions.

## Code style

- 4-space indent, PascalCase types, camelCase members.
- `let` over `var` wherever possible; `@State private var` for SwiftUI state.
- Prefer `async/await` over Combine for all new async work.
- No force-unwraps. Guard, `if let`, or `??`.
- Comments only when the *why* is non-obvious (e.g. the AppleScript-vs-.command
  decision above). Skip comments that just narrate the code.
- For new APIs you're unsure about (Liquid Glass, FoundationModels, recent
  SwiftUI), use `DocumentationSearch` — don't guess based on training data.

## Testing

Use Swift Testing (`import Testing`, `@Test`) for unit tests; XCUIAutomation
for UI tests. No tests are wired up yet — when adding a test target, mirror
the source folder layout under a `ClaudeUITests/` group.

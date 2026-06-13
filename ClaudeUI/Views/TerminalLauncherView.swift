import SwiftUI
import AppKit

struct TerminalLauncherView: View {
    let project: ClaudeProject?
    let session: ClaudeSession?

    @State private var launchError: String?

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(secondaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Button(action: launch) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(session != nil ? "Resume in Terminal" : "Open in Terminal")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(canLaunch ? Color.accentColor : Color.secondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canLaunch)
                .help(canLaunch ? "Launch Terminal in the project folder" : "Select a project first")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Failed to launch Terminal", isPresented: Binding(
            get: { launchError != nil },
            set: { if !$0 { launchError = nil } }
        )) {
            Button("OK") { launchError = nil }
        } message: {
            Text(launchError ?? "")
        }
    }

    private var canLaunch: Bool { project != nil }

    private var primaryLabel: String {
        session != nil ? "Continue this session in Terminal" : "Open project in Terminal"
    }

    private var secondaryLabel: String {
        guard let project else { return "No project selected" }
        if let session {
            return "\(project.projectPath) · claude --resume \(session.id)"
        }
        return project.projectPath
    }

    private func launch() {
        guard let project else { return }
        do {
            try TerminalLauncher.launch(projectPath: project.projectPath, sessionId: session?.id)
        } catch {
            launchError = error.localizedDescription
        }
    }
}

enum TerminalLauncher {
    enum LaunchError: LocalizedError {
        case writeFailed(String)
        case openFailed(String)

        var errorDescription: String? {
            switch self {
            case .writeFailed(let msg), .openFailed(let msg): return msg
            }
        }
    }

    static func launch(projectPath: String, sessionId: String?) throws {
        let claudeCommand: String
        if let sessionId, !sessionId.isEmpty {
            claudeCommand = "claude --resume \(escapeShellArg(sessionId))"
        } else {
            claudeCommand = "claude"
        }
        try run(command: claudeCommand, workingDirectory: projectPath)
    }

    /// Runs an arbitrary command in a fresh Terminal window. Used for
    /// interactive extension-management actions (e.g. `claude mcp add` that may
    /// trigger an OAuth flow) which need a TTY.
    static func run(command: String, workingDirectory: String?) throws {
        let cdLine = workingDirectory.map { "cd \(escapeShellArg($0)) || exit 1\n" } ?? ""

        // A .command file opens in Terminal.app via LaunchServices without
        // needing Automation (Apple Events) permission. The trailing
        // `exec $SHELL -l` keeps the window interactive after the command exits.
        let scriptBody = """
        #!/bin/bash
        \(cdLine)clear
        \(command)
        exec "$SHELL" -l
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-ui-\(UUID().uuidString).command")

        do {
            try scriptBody.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        } catch {
            throw LaunchError.writeFailed(error.localizedDescription)
        }

        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.open(
            [scriptURL],
            withApplicationAt: terminalURL,
            configuration: config,
            completionHandler: nil
        )
    }

    private static func escapeShellArg(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

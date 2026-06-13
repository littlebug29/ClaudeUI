import SwiftUI

@main
struct ClaudeUIApp: App {
    @StateObject private var sessionService = SessionService()
    @StateObject private var processManager = ClaudeProcessManager()
    @StateObject private var mcpService = MCPService()
    @StateObject private var pluginService = PluginService()
    @StateObject private var skillService = SkillService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionService)
                .environmentObject(processManager)
                .environmentObject(mcpService)
                .environmentObject(pluginService)
                .environmentObject(skillService)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    NotificationCenter.default.post(name: .newSession, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Refresh Sessions") {
                    Task { await sessionService.loadProjects() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra("ClaudeUI", systemImage: "bubble.left.and.text.bubble.right.fill") {
            MenuBarView()
                .environmentObject(sessionService)
                .environmentObject(processManager)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var sessionService: SessionService
    @EnvironmentObject private var processManager: ClaudeProcessManager

    var body: some View {
        let recent = sessionService.projects
            .flatMap(\.sessions)
            .sorted { $0.lastModifiedAt > $1.lastModifiedAt }
            .prefix(5)

        if recent.isEmpty {
            Text("No recent sessions")
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(recent)) { session in
                Button {
                    openSession(session)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.firstUserPrompt)
                                .lineLimit(1)
                            Text(session.relativeTimeString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if processManager.currentSessionId == session.id && processManager.isProcessing {
                            Spacer()
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }

        Divider()

        Button("Open ClaudeUI") {
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func openSession(_ session: ClaudeSession) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openSession, object: session.id)
    }
}

extension Notification.Name {
    static let newSession = Notification.Name("ClaudeUI.newSession")
    static let openSession = Notification.Name("ClaudeUI.openSession")
}

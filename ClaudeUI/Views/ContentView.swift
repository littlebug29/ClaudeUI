import SwiftUI

enum AppMode: String, CaseIterable, Identifiable {
    case sessions, mcp, plugins, skills
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sessions: return "Sessions"
        case .mcp: return "MCP"
        case .plugins: return "Plugins"
        case .skills: return "Skills"
        }
    }
    var symbol: String {
        switch self {
        case .sessions: return "bubble.left.and.text.bubble.right"
        case .mcp: return "server.rack"
        case .plugins: return "puzzlepiece.extension"
        case .skills: return "sparkles"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var sessionService: SessionService
    @EnvironmentObject private var processManager: ClaudeProcessManager

    @State private var mode: AppMode = .sessions
    @State private var selectedProject: ClaudeProject?
    @State private var selectedSession: ClaudeSession?
    @State private var selectedMCPName: String?
    @State private var selectedPluginId: String?
    @State private var selectedSkillId: String?
    @State private var showSettings = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    ForEach(AppMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                Divider()
                sidebar
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { showSettings = true } label: { Image(systemName: "gear") }
                        .help("Settings")
                }
            }
        } detail: {
            detail
        }
        .navigationTitle("")
        .task {
            await sessionService.loadProjects()
            // Auto-select most recent session
            if selectedSession == nil, let project = sessionService.projects.first {
                selectedProject = project
                selectedSession = project.sessions.first
                if let sid = selectedSession?.id {
                    processManager.currentSessionId = sid
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("Error", isPresented: Binding(
            get: { processManager.lastError != nil },
            set: { if !$0 { processManager.lastError = nil } }
        )) {
            Button("OK") { processManager.lastError = nil }
        } message: {
            Text(processManager.lastError ?? "")
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    @ViewBuilder
    private var sidebar: some View {
        switch mode {
        case .sessions:
            SessionListView(selectedProject: $selectedProject, selectedSession: $selectedSession)
        case .mcp:
            MCPListView(selectedName: $selectedMCPName)
        case .plugins:
            PluginBrowserView(selectedPluginId: $selectedPluginId)
        case .skills:
            SkillListView(selectedSkillId: $selectedSkillId)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch mode {
        case .sessions:
            ConversationView(session: selectedSession, project: selectedProject)
        case .mcp:
            MCPDetailView(serverName: selectedMCPName)
        case .plugins:
            PluginDetailView(pluginId: selectedPluginId)
        case .skills:
            SkillDetailView(skillId: selectedSkillId)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("claudeExecutablePath") private var claudeExecutablePath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Executable Path")
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack {
                    TextField(
                        "Auto-detect (\(ClaudeProcessManager.detectClaudePath()))",
                        text: $claudeExecutablePath
                    )
                    .textFieldStyle(.roundedBorder)
                    Button("Browse…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            claudeExecutablePath = url.path
                        }
                    }
                }
                Text("Leave blank to auto-detect from common install locations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 260)
    }
}

import AppKit

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionService: SessionService
    @EnvironmentObject private var processManager: ClaudeProcessManager

    @State private var selectedProject: ClaudeProject?
    @State private var selectedSession: ClaudeSession?
    @State private var showSettings = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SessionListView(
                selectedProject: $selectedProject,
                selectedSession: $selectedSession
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await sessionService.loadProjects() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh sessions")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .help("Settings")
                }
            }
        } detail: {
            ConversationView(
                session: selectedSession,
                project: selectedProject
            )
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
        .frame(minWidth: 700, minHeight: 500)
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

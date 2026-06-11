import SwiftUI

struct SessionListView: View {
    @EnvironmentObject private var sessionService: SessionService
    @EnvironmentObject private var processManager: ClaudeProcessManager

    @Binding var selectedProject: ClaudeProject?
    @Binding var selectedSession: ClaudeSession?

    @State private var searchText = ""
    @State private var expandedProjects: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if sessionService.isLoading {
                loadingView
            } else if sessionService.projects.isEmpty {
                emptyView
            } else {
                projectList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            expandedProjects = Set(sessionService.projects.map(\.id))
        }
        .onChange(of: sessionService.projects) { projects in
            for p in projects where !expandedProjects.contains(p.id) {
                expandedProjects.insert(p.id)
            }
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField("Search sessions", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)

        Divider()
    }

    @ViewBuilder
    private var loadingView: some View {
        Spacer()
        ProgressView()
            .scaleEffect(0.7)
        Spacer()
    }

    @ViewBuilder
    private var emptyView: some View {
        Spacer()
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No sessions found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Start Claude Code in a project\nto see sessions here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        Spacer()
    }

    @ViewBuilder
    private var projectList: some View {
        List(selection: $selectedSession) {
            ForEach(filteredProjects) { project in
                projectSection(project: project)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func projectSection(project: ClaudeProject) -> some View {
        Section {
            ForEach(filteredSessions(for: project)) { session in
                sessionRow(session: session, project: project)
                    .tag(session)
            }
        } header: {
            projectHeader(project: project)
        }
    }

    @ViewBuilder
    private func projectHeader(project: ClaudeProject) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            Text(project.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                newSession(for: project)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("New session in \(project.displayName)")
        }
    }

    @ViewBuilder
    private func sessionRow(session: ClaudeSession, project: ClaudeProject) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.firstUserPrompt)
                .font(.system(size: 13))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(session.relativeTimeString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                if processManager.currentSessionId == session.id && processManager.isProcessing {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("\(session.messageCount) msg")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedProject = project
            selectedSession = session
            processManager.currentSessionId = session.id
        }
    }

    private var filteredProjects: [ClaudeProject] {
        guard !searchText.isEmpty else { return sessionService.projects }
        return sessionService.projects.filter { project in
            project.displayName.localizedCaseInsensitiveContains(searchText) ||
            !filteredSessions(for: project).isEmpty
        }
    }

    private func filteredSessions(for project: ClaudeProject) -> [ClaudeSession] {
        guard !searchText.isEmpty else { return project.sessions }
        return project.sessions.filter { session in
            session.firstUserPrompt.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func newSession(for project: ClaudeProject) {
        selectedProject = project
        selectedSession = nil
        processManager.currentSessionId = nil
        processManager.streamingText = ""
    }
}

import Foundation
import Combine

@MainActor
final class SessionService: ObservableObject {
    @Published var projects: [ClaudeProject] = []
    @Published var isLoading = false

    private let claudeProjectsURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }()

    private var fsSource: DispatchSourceFileSystemObject?

    func loadProjects() async {
        isLoading = true
        let loaded = await Task.detached(priority: .userInitiated) { [claudeProjectsURL] in
            Self.discoverProjects(at: claudeProjectsURL)
        }.value
        projects = loaded.sorted {
            ($0.latestSession?.lastModifiedAt ?? .distantPast) >
            ($1.latestSession?.lastModifiedAt ?? .distantPast)
        }
        isLoading = false
        startWatching()
    }

    func loadMessages(for session: ClaudeSession) async -> [ConversationMessage] {
        await Task.detached(priority: .userInitiated) {
            Self.parseMessages(from: session.filePath)
        }.value
    }

    func refresh() async {
        await loadProjects()
    }

    private func startWatching() {
        fsSource?.cancel()
        guard let fd = opendir(claudeProjectsURL.path) else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: Int32(fd.pointee.__dd_fd),
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { await self?.refresh() }
        }
        source.resume()
        fsSource = source
    }

    nonisolated private static func discoverProjects(at url: URL) -> [ClaudeProject] {
        guard let slugs = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return [] }

        var projects: [ClaudeProject] = []

        for slugURL in slugs {
            let slug = slugURL.lastPathComponent
            guard slug != "memory" else { continue }
            guard (try? slugURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }

            let jsonlFiles = (try? FileManager.default.contentsOfDirectory(
                at: slugURL, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles
            ))?.filter { $0.pathExtension == "jsonl" } ?? []

            let sessions = jsonlFiles.compactMap { ClaudeSession.load(from: $0, projectSlug: slug) }
                .sorted { $0.lastModifiedAt > $1.lastModifiedAt }

            guard !sessions.isEmpty else { continue }

            // Prefer actual cwd from first session entry over slug-decoded path
            let projectPath = extractCwd(from: sessions.first?.filePath) ??
                              ClaudeProject.decodePath(from: slug)

            projects.append(ClaudeProject(id: slug, projectPath: projectPath, sessions: sessions))
        }

        return projects
    }

    nonisolated private static func extractCwd(from url: URL?) -> String? {
        guard let url,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }
        let data = handle.readData(ofLength: 4096)
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.components(separatedBy: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let cwd = entry["cwd"] as? String else { continue }
            return cwd
        }
        return nil
    }

    nonisolated private static func parseMessages(from url: URL) -> [ConversationMessage] {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return [] }

        var messages: [ConversationMessage] = []

        for line in text.components(separatedBy: "\n") {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }
            messages.append(contentsOf: ConversationMessage.parse(from: entry))
        }

        return messages
    }
}

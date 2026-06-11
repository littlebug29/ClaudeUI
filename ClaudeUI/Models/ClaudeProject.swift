import Foundation

struct ClaudeProject: Identifiable, Hashable {
    let id: String
    var projectPath: String
    var sessions: [ClaudeSession]

    var displayName: String {
        projectPath.split(separator: "/").last.map(String.init) ?? id
    }

    var latestSession: ClaudeSession? {
        sessions.max(by: { $0.lastModifiedAt < $1.lastModifiedAt })
    }

    static func == (lhs: ClaudeProject, rhs: ClaudeProject) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func decodePath(from slug: String) -> String {
        // slug like "-Users-khanh-CodingSpace-iOS-Mac-ClaudeUI"
        // becomes "/Users/khanh/CodingSpace/iOS_Mac/ClaudeUI"
        // Replace leading - with / then remaining - with /
        // This is a best-effort decode; the true path comes from session cwd field
        guard slug.hasPrefix("-") else { return slug }
        return "/" + slug.dropFirst().replacingOccurrences(of: "-", with: "/")
    }
}

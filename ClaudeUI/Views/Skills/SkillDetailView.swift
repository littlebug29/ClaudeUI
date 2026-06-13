import SwiftUI
import AppKit

struct SkillDetailView: View {
    @EnvironmentObject private var skillService: SkillService
    let skillId: String?

    private var skill: Skill? {
        skillService.skills.first { $0.id == skillId }
    }

    var body: some View {
        Group {
            if let skill {
                content(skill)
            } else {
                ContentUnavailableView("Select a skill", systemImage: "sparkles")
            }
        }
    }

    private func content(_ skill: Skill) -> some View {
        let report = SecurityScanner.scan(skill: skill)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(skill.name).font(.title2).fontWeight(.semibold).textSelection(.enabled)
                        Text(skill.source.label).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    SecurityBadge(severity: report.worstSeverity)
                }

                if !skill.description.isEmpty {
                    Text(skill.description).font(.system(size: 13)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if !skill.allowedTools.isEmpty {
                        field("Allowed tools", skill.allowedTools.joined(separator: ", "))
                    }
                    field("Auto-invoke", skill.autoInvokable ? "Yes — Claude may use it automatically" : "No")
                    field("Bundled scripts", skill.hasScripts ? "Yes" : "No")
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                SecurityReportView(report: report)

                HStack {
                    Button { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: skill.path) } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    if case .plugin = skill.source {
                        Text("Enable or disable this skill from its plugin in the Plugins tab.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 12)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

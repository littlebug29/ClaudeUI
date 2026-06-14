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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top, spacing: 13) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "sparkles")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.accentColor)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(skill.name)
                            .font(.system(size: 17, weight: .bold))
                            .textSelection(.enabled)
                        Text(metaLine(skill))
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    // Enable/disable only for plugin-provided skills (personal skills are always on)
                    if case .plugin = skill.source {
                        Text("Manage from Plugins tab")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)

                Divider()

                VStack(alignment: .leading, spacing: 22) {
                    // Description
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary.opacity(0.75))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Auto-invoke / allowed tools
                    VStack(alignment: .leading, spacing: 9) {
                        sectionLabel("When it runs")
                        Group {
                            if skill.autoInvokable {
                                Text("Claude may invoke this skill automatically based on context")
                            } else {
                                Text("Only invoked when explicitly referenced")
                            }
                        }
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .lineSpacing(2)
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 11))

                        if !skill.allowedTools.isEmpty {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(skill.allowedTools, id: \.self) { tool in
                                    Text(tool)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                }
                            }
                        }
                    }

                    SecurityReportView(report: report)

                    // Source / actions
                    VStack(alignment: .leading, spacing: 9) {
                        sectionLabel("Source")
                        HStack(spacing: 10) {
                            Text(skill.path)
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: skill.path)
                            } label: {
                                Label("Reveal", systemImage: "folder")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .kerning(0.7)
    }

    private func metaLine(_ skill: Skill) -> String {
        var parts = [skill.source.label]
        if skill.hasScripts { parts.append("Scripts") }
        return parts.joined(separator: " · ")
    }
}

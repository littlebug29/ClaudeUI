import SwiftUI

struct SkillListView: View {
    @EnvironmentObject private var skillService: SkillService
    @Binding var selectedSkillId: String?

    @State private var searchText = ""
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()

            if skillService.isLoading && skillService.skills.isEmpty {
                Spacer(); ProgressView().scaleEffect(0.7); Spacer()
            } else if skillService.skills.isEmpty {
                emptyView
            } else {
                List(selection: $selectedSkillId) {
                    if !personal.isEmpty {
                        Section("Personal") { ForEach(personal) { row($0) } }
                    }
                    if !plugin.isEmpty {
                        Section("From plugins") { ForEach(plugin) { row($0) } }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task { if skillService.skills.isEmpty { await skillService.load() } }
        .alert("New personal skill", isPresented: $showCreate) {
            TextField("skill-name", text: $newName)
            Button("Create") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { Task { await skillService.createPersonalSkill(named: name) } }
                newName = ""
            }
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("Scaffolds ~/.claude/skills/<name>/ via `claude plugin init`.")
        }
    }

    private var header: some View {
        HStack {
            Text("Skills").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            Button { Task { await skillService.load() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).help("Refresh")
            Button { showCreate = true } label: { Image(systemName: "plus") }
                .buttonStyle(.plain).help("New personal skill")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 12))
            TextField("Search skills", text: $searchText).textFieldStyle(.plain).font(.system(size: 13))
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 10).padding(.bottom, 8)
    }

    @ViewBuilder
    private var emptyView: some View {
        Spacer()
        VStack(spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(.quaternary)
            Text("No skills found").font(.subheadline).foregroundStyle(.secondary)
            Button("Create a personal skill") { showCreate = true }
        }.padding()
        Spacer()
    }

    private func row(_ skill: Skill) -> some View {
        let report = SecurityScanner.scan(skill: skill)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(skill.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if report.worstSeverity >= .warning {
                    SecurityBadge(severity: report.worstSeverity, compact: true)
                }
            }
            Text(skill.description)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .tag(skill.id)
    }

    private var filtered: [Skill] {
        skillService.skills.filter {
            searchText.isEmpty ||
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    private var personal: [Skill] { filtered.filter { if case .personal = $0.source { return true }; return false } }
    private var plugin: [Skill] { filtered.filter { if case .personal = $0.source { return false }; return true } }
}

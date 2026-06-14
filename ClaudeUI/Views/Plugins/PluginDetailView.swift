import SwiftUI

struct PluginDetailView: View {
    @EnvironmentObject private var pluginService: PluginService
    let pluginId: String?

    private var plugin: Plugin? {
        pluginService.plugins.first { $0.id == pluginId }
    }

    var body: some View {
        Group {
            if let plugin {
                content(plugin)
            } else {
                ContentUnavailableView("Select a plugin", systemImage: "puzzlepiece.extension")
            }
        }
    }

    private func content(_ plugin: Plugin) -> some View {
        let report = SecurityScanner.scan(plugin: plugin, marketplaceIsOfficial: pluginService.isOfficial(plugin))
        let busy = pluginService.busyPluginIds.contains(plugin.id)
        let letter = String(plugin.name.prefix(1)).uppercased()
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top, spacing: 15) {
                    Text(letter)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.accentColor.opacity(0.85))
                        .frame(width: 52, height: 52)
                        .background(Color.accentColor.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(plugin.name)
                            .font(.system(size: 19, weight: .bold))
                            .textSelection(.enabled)
                        Text(metaLine(plugin))
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    installButton(plugin, busy: busy)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 20)

                Divider()

                VStack(alignment: .leading, spacing: 22) {
                    // Description
                    if let desc = plugin.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary.opacity(0.75))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Components
                    if !plugin.bundledMCPServerNames.isEmpty || !plugin.skillNames.isEmpty || plugin.hasHooks {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("What it adds")
                            VStack(alignment: .leading, spacing: 9) {
                                if plugin.hasHooks {
                                    componentRow(icon: "bolt.horizontal.circle", label: "Lifecycle hooks", tint: Color.accentColor)
                                }
                                if !plugin.bundledMCPServerNames.isEmpty {
                                    componentRow(icon: "server.rack",
                                                 label: "MCP: \(plugin.bundledMCPServerNames.joined(separator: ", "))",
                                                 tint: Color(red: 0.239, green: 0.631, blue: 0.376))
                                }
                                if !plugin.skillNames.isEmpty {
                                    componentRow(icon: "sparkles",
                                                 label: "Skills: \(plugin.skillNames.joined(separator: ", "))",
                                                 tint: Color.orange)
                                }
                            }
                        }
                    }

                    // Stats row
                    let stats: [(String, String)] = [
                        plugin.installCount.map { ("Installs", "\($0)") },
                        plugin.version.flatMap { $0 != "unknown" ? ("Version", $0) : nil },
                        plugin.scope.map { ("Scope", $0.capitalized) },
                    ].compactMap { $0 }

                    if !stats.isEmpty {
                        Divider()
                        HStack(spacing: 30) {
                            ForEach(stats, id: \.0) { label, value in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(label.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .kerning(0.6)
                                    Text(value)
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            Spacer()
                        }
                    }

                    SecurityReportView(report: report)

                    if let url = plugin.sourceURL {
                        Link(destination: URL(string: url) ?? URL(string: "https://github.com")!) {
                            Label("View source", systemImage: "arrow.up.forward.square")
                        }.font(.caption)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
        }
    }

    @ViewBuilder
    private func installButton(_ plugin: Plugin, busy: Bool) -> some View {
        if busy {
            ProgressView().scaleEffect(0.75).frame(width: 90)
        } else if plugin.installed {
            Menu {
                Toggle("Enabled", isOn: Binding(
                    get: { plugin.enabled },
                    set: { v in Task { await pluginService.setEnabled(plugin, enabled: v) } }
                ))
                Divider()
                Button("Update") { Task { await pluginService.update(plugin) } }
                Button(role: .destructive) { Task { await pluginService.uninstall(plugin) } } label: {
                    Text("Uninstall")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.239, green: 0.631, blue: 0.376))
                    Text("Installed")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(red: 0.239, green: 0.631, blue: 0.376).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color(red: 0.239, green: 0.631, blue: 0.376).opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(Color(red: 0.239, green: 0.631, blue: 0.376))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } else {
            Button {
                Task { await pluginService.install(plugin) }
            } label: {
                Text("Install")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
        }
    }

    private func componentRow(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.8))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .kerning(0.7)
    }

    private func metaLine(_ plugin: Plugin) -> String {
        var parts = ["by \(plugin.marketplace)"]
        if let v = plugin.version, v != "unknown" { parts.append("v\(v)") }
        if let count = plugin.installCount { parts.append("\(count) installs") }
        return parts.joined(separator: " · ")
    }
}

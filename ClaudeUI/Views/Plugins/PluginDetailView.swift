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
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plugin.name).font(.title2).fontWeight(.semibold).textSelection(.enabled)
                        HStack(spacing: 6) {
                            Text(plugin.marketplace).font(.caption).foregroundStyle(.secondary)
                            if let v = plugin.version, v != "unknown" {
                                Text("· v\(v)").font(.caption).foregroundStyle(.secondary)
                            }
                            if let count = plugin.installCount {
                                Text("· \(count) installs").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    SecurityBadge(severity: report.worstSeverity)
                }

                if let description = plugin.description, !description.isEmpty {
                    Text(description).font(.system(size: 13)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                actionBar(plugin, busy: busy)

                if !plugin.bundledMCPServerNames.isEmpty || !plugin.skillNames.isEmpty || plugin.hasHooks {
                    componentInventory(plugin)
                }

                SecurityReportView(report: report)

                if let url = plugin.sourceURL {
                    Link(destination: URL(string: url) ?? URL(string: "https://github.com")!) {
                        Label("View source", systemImage: "arrow.up.forward.square")
                    }.font(.caption)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func actionBar(_ plugin: Plugin, busy: Bool) -> some View {
        HStack(spacing: 10) {
            if plugin.installed {
                Toggle("Enabled", isOn: Binding(
                    get: { plugin.enabled },
                    set: { newValue in Task { await pluginService.setEnabled(plugin, enabled: newValue) } }
                ))
                .toggleStyle(.switch)
                .disabled(busy)

                Button("Update") { Task { await pluginService.update(plugin) } }.disabled(busy)
                Button(role: .destructive) { Task { await pluginService.uninstall(plugin) } } label: {
                    Text("Uninstall")
                }.disabled(busy)
            } else {
                Button {
                    Task { await pluginService.install(plugin) }
                } label: {
                    Label("Install", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
            }
            if busy { ProgressView().scaleEffect(0.5) }
            Spacer()
        }
    }

    private func componentInventory(_ plugin: Plugin) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Components").font(.headline)
            if plugin.hasHooks {
                Label("Lifecycle hooks", systemImage: "bolt.horizontal.circle").font(.system(size: 12))
            }
            if !plugin.bundledMCPServerNames.isEmpty {
                Label("MCP: \(plugin.bundledMCPServerNames.joined(separator: ", "))", systemImage: "server.rack")
                    .font(.system(size: 12))
            }
            if !plugin.skillNames.isEmpty {
                Label("Skills: \(plugin.skillNames.joined(separator: ", "))", systemImage: "sparkles")
                    .font(.system(size: 12))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

import SwiftUI

struct PluginBrowserView: View {
    @EnvironmentObject private var pluginService: PluginService
    @Binding var selectedPluginId: String?

    @State private var searchText = ""
    @State private var marketplaceFilter = "All"
    @State private var showAddMarketplace = false

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()

            if pluginService.isLoading && pluginService.plugins.isEmpty {
                Spacer(); ProgressView().scaleEffect(0.7); Spacer()
            } else {
                List(selection: $selectedPluginId) {
                    if !installed.isEmpty {
                        Section("Installed") {
                            ForEach(installed) { row($0) }
                        }
                    }
                    if !available.isEmpty {
                        Section("Available") {
                            ForEach(available) { row($0) }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task { if pluginService.plugins.isEmpty { await pluginService.load() } }
        .sheet(isPresented: $showAddMarketplace) { AddMarketplaceSheet() }
    }

    private var header: some View {
        HStack {
            Text("Plugins").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            Menu {
                Picker("Marketplace", selection: $marketplaceFilter) {
                    Text("All marketplaces").tag("All")
                    ForEach(pluginService.marketplaces) { Text($0.name).tag($0.name) }
                }
                Divider()
                Button("Add marketplace…") { showAddMarketplace = true }
            } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                .menuStyle(.borderlessButton).fixedSize().help("Filter / add marketplace")
            Button { Task { await pluginService.load() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).help("Refresh")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 12))
            TextField("Search plugins", text: $searchText).textFieldStyle(.plain).font(.system(size: 13))
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 10).padding(.bottom, 8)
    }

    private func row(_ plugin: Plugin) -> some View {
        let report = SecurityScanner.scan(plugin: plugin, marketplaceIsOfficial: pluginService.isOfficial(plugin))
        let letter = String(plugin.name.prefix(1)).uppercased()
        return HStack(spacing: 9) {
            Text(letter)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.accentColor.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(plugin.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if plugin.installed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(red: 0.239, green: 0.631, blue: 0.376))
                    }
                    if plugin.installed && !plugin.enabled {
                        Text("Off")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text("by \(plugin.marketplace)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if pluginService.busyPluginIds.contains(plugin.id) {
                ProgressView().scaleEffect(0.5)
            }
            if report.worstSeverity >= .warning {
                SecurityBadge(severity: report.worstSeverity, compact: true)
            }
        }
        .padding(.vertical, 4)
        .tag(plugin.id)
    }

    // MARK: - Filtering

    private var filtered: [Plugin] {
        pluginService.plugins.filter { plugin in
            (marketplaceFilter == "All" || plugin.marketplace == marketplaceFilter) &&
            (searchText.isEmpty ||
             plugin.name.localizedCaseInsensitiveContains(searchText) ||
             (plugin.description?.localizedCaseInsensitiveContains(searchText) ?? false))
        }
    }
    private var installed: [Plugin] { filtered.filter(\.installed) }
    private var available: [Plugin] { filtered.filter { !$0.installed } }
}

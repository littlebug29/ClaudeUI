import SwiftUI

struct MCPDetailView: View {
    @EnvironmentObject private var mcpService: MCPService
    let serverName: String?

    @State private var detailed: MCPServer?
    @State private var showRemoveConfirm = false

    private var server: MCPServer? {
        detailed ?? mcpService.servers.first { $0.name == serverName }
    }

    var body: some View {
        Group {
            if let server {
                content(server)
            } else {
                ContentUnavailableView("Select an MCP server", systemImage: "server.rack")
            }
        }
        .task(id: serverName) {
            detailed = nil
            if let name = serverName { detailed = await mcpService.details(for: name) }
        }
    }

    private func content(_ server: MCPServer) -> some View {
        let report = SecurityScanner.scan(mcp: server)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name).font(.title2).fontWeight(.semibold).textSelection(.enabled)
                        Text(server.status.label).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    SecurityBadge(severity: report.worstSeverity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    field("Transport", server.transport.rawValue.uppercased())
                    if let url = server.url { field("URL", url) }
                    if let command = server.command { field("Command", command) }
                    if !server.args.isEmpty { field("Args", server.args.joined(separator: " ")) }
                    if !server.envKeys.isEmpty { field("Env vars", server.envKeys.joined(separator: ", ")) }
                    if !server.headerKeys.isEmpty { field("Headers", server.headerKeys.joined(separator: ", ")) }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                SecurityReportView(report: report)

                if !server.isPluginProvided {
                    Button(role: .destructive) {
                        showRemoveConfirm = true
                    } label: {
                        Label("Remove server", systemImage: "trash")
                    }
                } else {
                    Text("Provided by a plugin — manage it from the Plugins tab.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .confirmationDialog("Remove \(server.name)?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await mcpService.remove(server.name) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 12)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

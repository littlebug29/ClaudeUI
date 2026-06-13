import SwiftUI

struct MCPListView: View {
    @EnvironmentObject private var mcpService: MCPService
    @Binding var selectedName: String?
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if mcpService.isLoading {
                Spacer(); ProgressView().scaleEffect(0.7); Spacer()
            } else if mcpService.servers.isEmpty {
                emptyView
            } else {
                List(selection: $selectedName) {
                    ForEach(mcpService.servers) { server in
                        row(server).tag(server.name)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task { if mcpService.servers.isEmpty { await mcpService.load() } }
        .sheet(isPresented: $showAddSheet) { AddMCPServerSheet() }
    }

    private var header: some View {
        HStack {
            Text("MCP Servers").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            Button { Task { await mcpService.load() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).help("Refresh")
            Button { showAddSheet = true } label: { Image(systemName: "plus") }
                .buttonStyle(.plain).help("Add MCP server")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    @ViewBuilder
    private var emptyView: some View {
        Spacer()
        VStack(spacing: 10) {
            Image(systemName: "server.rack").font(.system(size: 28)).foregroundStyle(.quaternary)
            Text("No MCP servers").font(.subheadline).foregroundStyle(.secondary)
            Button("Add a server") { showAddSheet = true }
        }
        .padding()
        Spacer()
    }

    private func row(_ server: MCPServer) -> some View {
        let report = SecurityScanner.scan(mcp: server)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(server.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer()
                if report.worstSeverity >= .warning {
                    SecurityBadge(severity: report.worstSeverity, compact: true)
                }
            }
            HStack(spacing: 6) {
                statusDot(server.status)
                Text(server.status.label).font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Text(server.transport.rawValue.uppercased()).font(.caption2).foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, 2)
    }

    private func statusDot(_ status: MCPServer.Status) -> some View {
        let color: Color = {
            switch status {
            case .connected: return .green
            case .needsAuth, .pending: return .orange
            case .failed: return .red
            case .unknown: return .secondary
            }
        }()
        return Circle().fill(color).frame(width: 6, height: 6)
    }
}

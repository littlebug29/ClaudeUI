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
        let dotColor = statusColor(server.status)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(dotColor.opacity(0.18)).frame(width: 14, height: 14)
                    Circle().fill(dotColor).frame(width: 8, height: 8)
                }
                Text(server.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if report.worstSeverity >= .warning {
                    SecurityBadge(severity: report.worstSeverity, compact: true)
                }
                Text(server.transport.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Text(statusSubline(server))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.leading, 14)
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: MCPServer.Status) -> Color {
        switch status {
        case .connected: return Color(red: 0.239, green: 0.631, blue: 0.376)
        case .failed: return Color(red: 0.839, green: 0.271, blue: 0.239)
        case .needsAuth, .pending: return .orange
        case .unknown: return Color.secondary
        }
    }

    private func statusSubline(_ server: MCPServer) -> String {
        switch server.status {
        case .connected: return server.url ?? "Connected"
        case .failed: return "Failed to connect"
        case .needsAuth: return "Needs authentication"
        case .pending: return "Pending approval"
        case .unknown: return server.url ?? server.command ?? ""
        }
    }
}

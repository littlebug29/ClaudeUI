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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top, spacing: 13) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "server.rack")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.accentColor)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(server.name)
                            .font(.system(size: 17, weight: .bold))
                            .textSelection(.enabled)
                        Text(server.transport.rawValue.uppercased()
                             + (server.isPluginProvided ? " · Plugin" : " · User"))
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    statusBadge(server.status)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)

                Divider()

                VStack(alignment: .leading, spacing: 22) {
                    // Error panel
                    if server.status == .failed {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Color(red: 0.839, green: 0.271, blue: 0.239))
                                .font(.system(size: 15))
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Connection failed")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.7, green: 0.22, blue: 0.2))
                                Text("Could not reach server — check the command or URL")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Color(red: 0.6, green: 0.34, blue: 0.31))
                            }
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.84, green: 0.27, blue: 0.24).opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(Color(red: 0.84, green: 0.27, blue: 0.24).opacity(0.2), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    }

                    // Command / URL
                    if let cmd = commandString(server) {
                        VStack(alignment: .leading, spacing: 9) {
                            sectionLabel("Command")
                            Text(cmd)
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundStyle(Color(red: 0.902, green: 0.890, blue: 0.863))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(red: 0.122, green: 0.118, blue: 0.133))
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                                .textSelection(.enabled)
                        }
                    }

                    // Env / header keys as chips
                    let allKeys = server.envKeys + server.headerKeys
                    if !allKeys.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Configuration")
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(allKeys, id: \.self) { key in
                                    Text(key)
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

                    if !server.isPluginProvided {
                        Button(role: .destructive) {
                            showRemoveConfirm = true
                        } label: {
                            Label("Remove server", systemImage: "trash")
                        }
                    } else {
                        Text("Provided by a plugin — manage it from the Plugins tab.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
        }
        .confirmationDialog("Remove \(server.name)?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await mcpService.remove(server.name) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: MCPServer.Status) -> some View {
        let color: Color = {
            switch status {
            case .connected: return Color(red: 0.239, green: 0.631, blue: 0.376)
            case .failed: return Color(red: 0.839, green: 0.271, blue: 0.239)
            case .needsAuth, .pending: return .orange
            case .unknown: return .secondary
            }
        }()
        let label: String = {
            switch status {
            case .connected: return "Connected"
            case .failed: return "Failed"
            case .needsAuth: return "Needs Auth"
            case .pending: return "Pending"
            case .unknown: return "Unknown"
            }
        }()
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .kerning(0.7)
    }

    private func commandString(_ server: MCPServer) -> String? {
        var parts: [String] = []
        if let cmd = server.command { parts.append(cmd) }
        if let url = server.url { parts.append(url) }
        parts += server.args
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

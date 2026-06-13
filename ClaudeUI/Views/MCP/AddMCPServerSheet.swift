import SwiftUI

struct AddMCPServerSheet: View {
    @EnvironmentObject private var mcpService: MCPService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var transport: MCPServer.Transport = .http
    @State private var target = ""
    @State private var scope = "user"
    @State private var pairs: [KeyValue] = []
    @State private var launchError: String?

    private struct KeyValue: Identifiable { let id = UUID(); var key = ""; var value = "" }

    private var isStdio: Bool { transport == .stdio }
    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !target.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add MCP Server").font(.title2).fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                Picker("Transport", selection: $transport) {
                    Text("HTTP").tag(MCPServer.Transport.http)
                    Text("SSE").tag(MCPServer.Transport.sse)
                    Text("stdio (local command)").tag(MCPServer.Transport.stdio)
                }
                TextField(isStdio ? "Command (e.g. npx my-mcp-server)" : "URL", text: $target)
                Picker("Scope", selection: $scope) {
                    Text("User (all projects)").tag("user")
                    Text("Local (this machine)").tag("local")
                    Text("Project (shared via .mcp.json)").tag("project")
                }

                Section(isStdio ? "Environment variables" : "Headers") {
                    ForEach($pairs) { $pair in
                        HStack {
                            TextField("Key", text: $pair.key)
                            TextField("Value", text: $pair.value)
                            Button { pairs.removeAll { $0.id == pair.id } } label: {
                                Image(systemName: "minus.circle")
                            }.buttonStyle(.plain)
                        }
                    }
                    Button { pairs.append(KeyValue()) } label: {
                        Label(isStdio ? "Add variable" : "Add header", systemImage: "plus")
                    }
                }
            }
            .formStyle(.grouped)

            Text("This opens Terminal to run `claude mcp add`, so any sign-in or trust prompt happens in the official CLI.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add in Terminal") { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(width: 520, height: 540)
        .alert("Couldn't launch Terminal", isPresented: Binding(
            get: { launchError != nil }, set: { if !$0 { launchError = nil } }
        )) { Button("OK") { launchError = nil } } message: { Text(launchError ?? "") }
    }

    private func add() {
        var headers: [String: String] = [:]
        var env: [String: String] = [:]
        for pair in pairs where !pair.key.trimmingCharacters(in: .whitespaces).isEmpty {
            if isStdio { env[pair.key] = pair.value } else { headers[pair.key] = pair.value }
        }
        let command = mcpService.addCommand(
            name: name.trimmingCharacters(in: .whitespaces),
            transport: transport,
            target: target.trimmingCharacters(in: .whitespaces),
            headers: headers, env: env, scope: scope
        )
        do {
            try TerminalLauncher.run(command: command, workingDirectory: nil)
            dismiss()
        } catch {
            launchError = error.localizedDescription
        }
    }
}

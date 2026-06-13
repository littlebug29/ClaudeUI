import SwiftUI

struct AddMarketplaceSheet: View {
    @EnvironmentObject private var pluginService: PluginService
    @Environment(\.dismiss) private var dismiss

    @State private var source = ""
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Marketplace").font(.title2).fontWeight(.semibold)

            Text("Enter a GitHub repo (owner/repo), a git URL, or a local path. Claude Code will fetch its plugin catalog.")
                .font(.subheadline).foregroundStyle(.secondary)

            TextField("anthropics/claude-plugins-official", text: $source)
                .textFieldStyle(.roundedBorder)

            if let error = pluginService.lastError {
                Text(error).font(.caption).foregroundStyle(.red).lineLimit(3)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    working = true
                    Task {
                        await pluginService.addMarketplace(source.trimmingCharacters(in: .whitespaces))
                        working = false
                        if pluginService.lastError == nil { dismiss() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(source.trimmingCharacters(in: .whitespaces).isEmpty || working)
            }
        }
        .padding(20)
        .frame(width: 460, height: 220)
    }
}

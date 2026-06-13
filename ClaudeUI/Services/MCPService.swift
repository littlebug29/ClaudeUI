import Foundation
import Combine

@MainActor
final class MCPService: ObservableObject {
    @Published var servers: [MCPServer] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let cli = ClaudeCLI()

    func load() async {
        isLoading = true
        lastError = nil
        do {
            let output = try await cli.run(["mcp", "list"])
            servers = Self.parseList(output.stdout)
        } catch {
            lastError = error.localizedDescription
            servers = []
        }
        isLoading = false
    }

    /// Fetches richer detail for one server (command, args, env/header key names).
    func details(for name: String) async -> MCPServer? {
        guard let base = servers.first(where: { $0.name == name }) else { return nil }
        guard let output = try? await cli.run(["mcp", "get", name]).stdout else { return base }
        return Self.parseGet(output, fallback: base)
    }

    func remove(_ name: String) async {
        do {
            try await cli.runChecked(["mcp", "remove", name])
            await load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Builds the `claude mcp add …` command for interactive hand-off to Terminal.
    /// Adding is routed through Terminal because remote servers frequently kick
    /// off an OAuth flow that needs a TTY.
    func addCommand(name: String, transport: MCPServer.Transport, target: String,
                    headers: [String: String], env: [String: String], scope: String) -> String {
        var args = ["mcp", "add", "-s", scope]
        if transport != .stdio {
            args += ["-t", transport.rawValue]
        }
        for (key, value) in headers where !key.isEmpty {
            args += ["-H", "\(key): \(value)"]
        }
        for (key, value) in env where !key.isEmpty {
            args += ["-e", "\(key)=\(value)"]
        }
        args.append(name)
        args.append(target)
        return cli.terminalCommand(args)
    }

    // MARK: - Parsing

    /// Parses `claude mcp list`. Lines look like:
    ///   `name: https://host/mcp (HTTP) - ✘ Failed to connect`
    /// The server name may itself contain colons (e.g. `plugin:figma:figma`),
    /// but never a colon *followed by a space*, so we split on the first ": ".
    nonisolated static func parseList(_ text: String) -> [MCPServer] {
        var result: [MCPServer] = []
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, line.contains(": "),
                  !line.hasPrefix("Checking") else { continue }

            guard let sep = line.range(of: ": ") else { continue }
            let name = String(line[..<sep.lowerBound])
            var remainder = String(line[sep.upperBound...])

            var status: MCPServer.Status = .unknown
            if let dash = remainder.range(of: " - ", options: .backwards) {
                let statusText = String(remainder[dash.upperBound...])
                status = parseStatus(statusText)
                remainder = String(remainder[..<dash.lowerBound])
            }

            var transport: MCPServer.Transport = .stdio
            if let paren = remainder.range(of: " (") {
                let t = remainder[paren.upperBound...].prefix(while: { $0 != ")" })
                transport = MCPServer.Transport(rawValue: t.lowercased()) ?? .unknown
                remainder = String(remainder[..<paren.lowerBound])
            }

            let target = remainder.trimmingCharacters(in: .whitespaces)
            let isURL = target.hasPrefix("http://") || target.hasPrefix("https://")
            if isURL && transport == .stdio { transport = .http }

            result.append(MCPServer(
                name: name,
                transport: transport,
                url: isURL ? target : nil,
                command: isURL ? nil : (target.isEmpty ? nil : target),
                args: [],
                envKeys: [],
                headerKeys: [],
                status: status
            ))
        }
        return result
    }

    /// Parses `claude mcp get <name>` (line-oriented `Key: value`) to enrich a server.
    nonisolated static func parseGet(_ text: String, fallback: MCPServer) -> MCPServer {
        var type = fallback.transport
        var url = fallback.url
        var command = fallback.command
        var args = fallback.args
        var envKeys = fallback.envKeys
        var headerKeys = fallback.headerKeys

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let colon = line.range(of: ":") else { continue }
            let key = line[..<colon.lowerBound].trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            switch key {
            case "type": type = MCPServer.Transport(rawValue: value.lowercased()) ?? type
            case "url": url = value
            case "command": command = value
            case "args": args = value.split(separator: " ").map(String.init)
            case "environment", "env":
                envKeys = splitKeyNames(value)
            case "headers", "header":
                headerKeys = splitKeyNames(value)
            default: break
            }
        }

        return MCPServer(
            name: fallback.name, transport: type, url: url, command: command,
            args: args, envKeys: envKeys, headerKeys: headerKeys, status: fallback.status
        )
    }

    /// Extracts key names from a comma-separated list that may be `KEY=…` or `KEY: …`.
    nonisolated private static func splitKeyNames(_ value: String) -> [String] {
        value.split(separator: ",").map { part in
            let token = part.trimmingCharacters(in: .whitespaces)
            if let eq = token.firstIndex(where: { $0 == "=" || $0 == ":" }) {
                return String(token[..<eq]).trimmingCharacters(in: .whitespaces)
            }
            return token
        }.filter { !$0.isEmpty }
    }

    nonisolated private static func parseStatus(_ text: String) -> MCPServer.Status {
        let lower = text.lowercased()
        if lower.contains("needs authentication") { return .needsAuth }
        if lower.contains("failed") { return .failed }
        if lower.contains("pending") { return .pending }
        if lower.contains("connected") || lower.contains("✓") { return .connected }
        return .unknown
    }
}

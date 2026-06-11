import Foundation
import Combine

@MainActor
final class ClaudeProcessManager: ObservableObject {
    @Published var isProcessing = false
    @Published var streamingText = ""
    @Published var currentSessionId: String?
    @Published var lastError: String?

    private var process: Process?
    private var stdinPipe: Pipe?

    var claudeExecutablePath: String {
        UserDefaults.standard.string(forKey: "claudeExecutablePath") ?? Self.detectClaudePath()
    }

    static func detectClaudePath() -> String {
        let candidates = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        // Fallback: try which via shell
        if let path = runWhichClaude() { return path }
        return "/opt/homebrew/bin/claude"
    }

    private static func runWhichClaude() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = ["claude"]
        let stdout = Pipe()
        p.standardOutput = stdout
        p.standardError = Pipe()

        do {
            try p.run()
        } catch {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        guard p.terminationStatus == 0 else { return nil }
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }

    func sendMessage(
        _ prompt: String,
        projectPath: String,
        sessionId: String?,
        onEvent: @escaping (StreamEvent) -> Void
    ) async {
        guard !isProcessing else { return }

        isProcessing = true
        streamingText = ""
        lastError = nil

        let execPath = claudeExecutablePath
        let sid = sessionId

        await Task.detached(priority: .userInitiated) {
            var args = ["-p", "--output-format", "stream-json", "--include-partial-messages"]
            if let sid { args += ["--resume", sid] }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                await MainActor.run {
                    onEvent(.error("Failed to launch claude: \(error.localizedDescription)"))
                }
                return
            }

            // Write prompt to stdin then close
            let promptData = (prompt + "\n").data(using: .utf8) ?? Data()
            stdinPipe.fileHandleForWriting.write(promptData)
            stdinPipe.fileHandleForWriting.closeFile()

            // Read all stdout (blocks until process closes the write end)
            let stdoutHandle = stdoutPipe.fileHandleForReading
            let outputData = stdoutHandle.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            for line in output.components(separatedBy: "\n") {
                if let event = StreamParser.parse(line: line) {
                    await MainActor.run { onEvent(event) }
                }
            }

            process.waitUntilExit()
        }.value

        isProcessing = false
    }

    func stopSession() {
        process?.terminate()
        process = nil
        isProcessing = false
    }
}

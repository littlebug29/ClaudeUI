import Foundation

/// Central wrapper around the `claude` CLI used by the extension-manager
/// features (MCP / plugins / skills). Read operations run in-process and
/// capture output; interactive operations (OAuth, trust prompts) are handed
/// off to Terminal via `terminalCommand(_:)` + `TerminalLauncher`.
struct ClaudeCLI {
    enum CLIError: LocalizedError {
        case launchFailed(String)
        case nonZeroExit(code: Int32, message: String)
        case decodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let msg): return "Failed to launch claude: \(msg)"
            case .nonZeroExit(_, let message): return message
            case .decodeFailed(let msg): return "Could not parse claude output: \(msg)"
            }
        }
    }

    struct Output {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    let executablePath: String

    init(executablePath: String? = nil) {
        self.executablePath = executablePath ?? ClaudeProcessManager.detectClaudePath()
    }

    func run(_ args: [String], currentDirectory: String? = nil) async throws -> Output {
        let execPath = executablePath
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = args
            if let currentDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
            }

            // GUI apps inherit launchd's minimal PATH, which omits the dirs where
            // claude finds node/git/uv. Prepend the common ones so subprocesses
            // resolve (mirrors the rationale behind detectClaudePath()).
            var env = ProcessInfo.processInfo.environment
            let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
            let existing = env["PATH"].map { [$0] } ?? []
            env["PATH"] = (extraPaths + existing).joined(separator: ":")
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                throw CLIError.launchFailed(error.localizedDescription)
            }

            // Read both pipes before waitUntilExit() to avoid the ~64KB
            // pipe-buffer deadlock when the child outdoes a single buffer.
            let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return Output(
                stdout: String(data: outData, encoding: .utf8) ?? "",
                stderr: String(data: errData, encoding: .utf8) ?? "",
                exitCode: process.terminationStatus
            )
        }.value
    }

    /// Runs and requires exit code 0, returning stdout.
    @discardableResult
    func runChecked(_ args: [String], currentDirectory: String? = nil) async throws -> String {
        let output = try await run(args, currentDirectory: currentDirectory)
        guard output.exitCode == 0 else {
            let message = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? output.stdout : output.stderr
            throw CLIError.nonZeroExit(code: output.exitCode, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output.stdout
    }

    func runJSON<T: Decodable>(_ type: T.Type, _ args: [String]) async throws -> T {
        let stdout = try await runChecked(args)
        guard let data = stdout.data(using: .utf8), !data.isEmpty else {
            throw CLIError.decodeFailed("empty output")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CLIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Runs claude with `input` written to stdin. Used for one-shot prompts
    /// such as session-name suggestion (`claude -p`).
    func runWithStdin(args: [String], input: String) async throws -> Output {
        let execPath = executablePath
        let inputData = (input + "\n").data(using: .utf8) ?? Data()
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = args

            var env = ProcessInfo.processInfo.environment
            let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
            let existing = env["PATH"].map { [$0] } ?? []
            env["PATH"] = (extraPaths + existing).joined(separator: ":")
            process.environment = env

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do { try process.run() } catch {
                throw CLIError.launchFailed(error.localizedDescription)
            }

            // Close stdin after writing so the child sees EOF.
            stdinPipe.fileHandleForWriting.write(inputData)
            stdinPipe.fileHandleForWriting.closeFile()

            // Read both pipes before waitUntilExit to avoid pipe-buffer deadlock.
            let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return Output(
                stdout: String(data: outData, encoding: .utf8) ?? "",
                stderr: String(data: errData, encoding: .utf8) ?? "",
                exitCode: process.terminationStatus
            )
        }.value
    }

    /// Builds a single shell command string (executable + escaped args) suitable
    /// for handing to `TerminalLauncher` when an action needs an interactive TTY.
    func terminalCommand(_ args: [String]) -> String {
        ([executablePath] + args).map(Self.escape).joined(separator: " ")
    }

    static func escape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

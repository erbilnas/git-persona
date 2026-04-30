import Foundation

enum GitConfigApplierError: LocalizedError, Equatable {
    case gitNotFound
    case commandFailed(exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return "Git executable not found in PATH."
        case let .commandFailed(code, stderr):
            let tail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if tail.isEmpty {
                return "Git exited with code \(code)."
            }
            return "Git error (code \(code)): \(tail)"
        }
    }
}

struct GitConfigApplier: Sendable {
    private let gitPath: String

    init(gitPath: String = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    func resolvedGitPath() -> String {
        if FileManager.default.isExecutableFile(atPath: gitPath) {
            return gitPath
        }
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in envPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent("git").path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return gitPath
    }

    func readLocalUser(repoRoot: String) throws -> (name: String?, email: String?) {
        let name = try runGit(args: ["-C", repoRoot, "config", "--local", "user.name"], write: false).stdout.nilIfEmpty
        let email = try runGit(args: ["-C", repoRoot, "config", "--local", "user.email"], write: false).stdout.nilIfEmpty
        return (name, email)
    }

    func readGlobalUser() throws -> (name: String?, email: String?) {
        let name = try runGit(args: ["config", "--global", "user.name"], write: false).stdout.nilIfEmpty
        let email = try runGit(args: ["config", "--global", "user.email"], write: false).stdout.nilIfEmpty
        return (name, email)
    }

    func applyLocal(persona: Persona, repoRoot: String) throws {
        let git = resolvedGitPath()
        guard FileManager.default.isExecutableFile(atPath: git) else {
            throw GitConfigApplierError.gitNotFound
        }
        _ = try runGit(args: ["-C", repoRoot, "config", "--local", "user.name", persona.gitUserName], write: true, executable: git)
        _ = try runGit(args: ["-C", repoRoot, "config", "--local", "user.email", persona.gitUserEmail], write: true, executable: git)
        if let key = persona.signingKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            _ = try runGit(args: ["-C", repoRoot, "config", "--local", "user.signingkey", key], write: true, executable: git)
        }
    }

    func applyGlobal(persona: Persona) throws {
        let git = resolvedGitPath()
        guard FileManager.default.isExecutableFile(atPath: git) else {
            throw GitConfigApplierError.gitNotFound
        }
        _ = try runGit(args: ["config", "--global", "user.name", persona.gitUserName], write: true, executable: git)
        _ = try runGit(args: ["config", "--global", "user.email", persona.gitUserEmail], write: true, executable: git)
        if let key = persona.signingKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            _ = try runGit(args: ["config", "--global", "user.signingkey", key], write: true, executable: git)
        }
    }

    private func runGit(
        args: [String],
        write: Bool,
        executable: String? = nil
    ) throws -> (stdout: String, stderr: String) {
        let exec = executable ?? resolvedGitPath()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exec)
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        if write {
            process.standardInput = Pipe()
        }

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            // For read paths, missing config returns 1 — treat as empty
            if !write && process.terminationStatus == 1 {
                return ("", stderr)
            }
            throw GitConfigApplierError.commandFailed(exitCode: process.terminationStatus, stderr: stderr)
        }
        return (stdout, stderr)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

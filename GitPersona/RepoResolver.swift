import Foundation

enum RepoResolverError: LocalizedError, Equatable {
    case gitNotFound
    case notAGitRepository(stderr: String)

    var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return "Git executable not found in PATH."
        case let .notAGitRepository(stderr):
            let tail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return tail.isEmpty ? "Selected folder is not a Git repository." : tail
        }
    }
}

struct RepoResolver: Sendable {
    private let applier: GitConfigApplier

    init(applier: GitConfigApplier = GitConfigApplier()) {
        self.applier = applier
    }

    func gitTopLevel(forDirectory directory: URL) throws -> String {
        let git = applier.resolvedGitPath()
        guard FileManager.default.isExecutableFile(atPath: git) else {
            throw RepoResolverError.gitNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = ["-C", directory.path, "rev-parse", "--show-toplevel"]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw RepoResolverError.notAGitRepository(stderr: stderr)
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation
import Observation

@Observable
@MainActor
final class PersonaStore {
    private(set) var document: PersonaDocument
    private let storeURL: URL
    private let legacyPlainURL: URL
    private let maxRecentRepos = 12

    var personas: [Persona] {
        document.personas
    }

    var lastRepoPaths: [String] {
        document.lastRepoPaths
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appendingPathComponent("dev.gitpersona.app", isDirectory: true)
        self.storeURL = folder.appendingPathComponent("personas.store", isDirectory: false)
        self.legacyPlainURL = folder.appendingPathComponent("personas.json", isDirectory: false)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        if let doc = Self.loadDocument(storeURL: storeURL, legacyPlainURL: legacyPlainURL) {
            self.document = doc
        } else {
            self.document = PersonaDocument()
            persist()
        }
        if FileManager.default.fileExists(atPath: legacyPlainURL.path) {
            persist()
        }
    }

    private static func loadDocument(storeURL: URL, legacyPlainURL: URL) -> PersonaDocument? {
        let fm = FileManager.default

        if fm.fileExists(atPath: storeURL.path),
           let wrapped = try? Data(contentsOf: storeURL),
           wrapped.count > 4
        {
            do {
                let plain = try PersonaVault.decrypt(wrapped)
                return try JSONDecoder().decode(PersonaDocument.self, from: plain)
            } catch {
                Self.backupCorruptEncryptedFile(storeURL)
                if fm.fileExists(atPath: legacyPlainURL.path),
                   let data = try? Data(contentsOf: legacyPlainURL),
                   let decoded = try? JSONDecoder().decode(PersonaDocument.self, from: data)
                {
                    return decoded
                }
                return nil
            }
        }

        if fm.fileExists(atPath: legacyPlainURL.path),
           let data = try? Data(contentsOf: legacyPlainURL),
           let decoded = try? JSONDecoder().decode(PersonaDocument.self, from: data)
        {
            return decoded
        }

        return nil
    }

    private static func backupCorruptEncryptedFile(_ url: URL) {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dest = url.deletingLastPathComponent().appendingPathComponent("personas.store.corrupt-\(stamp)")
        try? FileManager.default.moveItem(at: url, to: dest)
    }

    func upsert(_ persona: Persona) {
        if let idx = document.personas.firstIndex(where: { $0.id == persona.id }) {
            document.personas[idx] = persona
        } else {
            document.personas.append(persona)
        }
        persist()
    }

    func delete(id: UUID) {
        document.personas.removeAll { $0.id == id }
        persist()
    }

    func movePersonas(fromOffsets source: IndexSet, toOffset destination: Int) {
        document.personas.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// Returns the new persona’s id.
    func duplicatePersona(id: UUID) -> UUID? {
        guard let p = persona(id: id) else { return nil }
        let name = p.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = name.isEmpty ? "Persona" : name
        let copy = Persona(
            displayName: "\(suffix) Copy",
            gitUserName: p.gitUserName,
            gitUserEmail: p.gitUserEmail,
            signingKey: p.signingKey,
            notes: p.notes
        )
        upsert(copy)
        return copy.id
    }

    func persona(id: UUID?) -> Persona? {
        guard let id else { return nil }
        return document.personas.first { $0.id == id }
    }

    func recordRepoPath(_ path: String) {
        let normalized = (path as NSString).standardizingPath
        var paths = document.lastRepoPaths.filter { $0 != normalized }
        paths.insert(normalized, at: 0)
        if paths.count > maxRecentRepos {
            paths = Array(paths.prefix(maxRecentRepos))
        }
        document.lastRepoPaths = paths
        persist()
    }

    private func persist() {
        do {
            let json = try JSONEncoder().encode(document)
            let wrapped = try PersonaVault.encrypt(json)
            try wrapped.write(to: storeURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: legacyPlainURL.path) {
                try? FileManager.default.removeItem(at: legacyPlainURL)
            }
        } catch {
            // Non-fatal; UI could show alert if needed
        }
    }
}

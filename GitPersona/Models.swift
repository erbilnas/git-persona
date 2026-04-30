import Foundation

struct Persona: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var displayName: String
    var gitUserName: String
    var gitUserEmail: String
    var signingKey: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        gitUserName: String,
        gitUserEmail: String,
        signingKey: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.gitUserName = gitUserName
        self.gitUserEmail = gitUserEmail
        self.signingKey = signingKey
        self.notes = notes
    }
}

struct PersonaDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var personas: [Persona]
    /// Most recently used repo roots (bounded).
    var lastRepoPaths: [String]

    init(version: Int = Self.currentVersion, personas: [Persona] = [], lastRepoPaths: [String] = []) {
        self.version = version
        self.personas = personas
        self.lastRepoPaths = lastRepoPaths
    }
}

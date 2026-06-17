import AppKit
import SwiftUI

// MARK: - General

struct GeneralSettingsPane: View {
    @State private var launchAtLoginRefresh = 0
    @State private var launchAtLoginError: String?

    var body: some View {
        SettingsDetailScaffold(title: "General") {
            SettingsForm(
                footer: "Launch GitPersona when you log in to this Mac."
            ) {
                Toggle("Open at login", isOn: openAtLoginBinding)
                    .id(launchAtLoginRefresh)

                if LaunchAtLogin.needsUserApproval {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Approve GitPersona under Login Items to finish enabling start at login.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Login Items…") {
                            LaunchAtLogin.openLoginItemsSettings()
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                }
            }
        }
        .onAppear { launchAtLoginRefresh += 1 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLoginRefresh += 1
        }
        .alert("Open at login", isPresented: Binding(
            get: { launchAtLoginError != nil },
            set: { if !$0 { launchAtLoginError = nil } }
        )) {
            Button("OK", role: .cancel) { launchAtLoginError = nil }
        } message: {
            Text(launchAtLoginError ?? "")
        }
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                LaunchAtLogin.isEnabled || LaunchAtLogin.needsUserApproval
            },
            set: { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    launchAtLoginRefresh += 1
                } catch {
                    launchAtLoginError = error.localizedDescription
                }
            }
        )
    }
}

// MARK: - Personas

struct PersonasSettingsPane: View {
    @Environment(PersonaStore.self) private var store
    @State private var selection: UUID?
    @State private var personaPendingDeletion: Persona?
    @FocusState private var focusedField: PersonaFocusField?

    private enum PersonaFocusField: Hashable {
        case displayName
        case gitUserName
        case gitEmail
        case signingKey
        case notes
    }

    var body: some View {
        SettingsDetailScaffold(title: "Personas") {
            HStack(alignment: .top, spacing: 0) {
                personaListColumn
                    .frame(width: 220)

                Divider()

                personaEditorColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 400)
        }
        .onAppear {
            if selection == nil {
                selection = store.personas.first?.id
            }
        }
        .onChange(of: store.personas.count) { _, count in
            if count == 0 {
                selection = nil
            } else if let id = selection, store.persona(id: id) == nil {
                selection = store.personas.first?.id
            }
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { personaPendingDeletion != nil },
                set: { if !$0 { personaPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = personaPendingDeletion {
                    store.delete(id: p.id)
                    selection = store.personas.first?.id
                }
                personaPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                personaPendingDeletion = nil
            }
        } message: {
            Text("This removes the saved persona from GitPersona. Your Git configs are not changed.")
        }
    }

    private var deleteDialogTitle: String {
        guard let p = personaPendingDeletion else { return "" }
        return "Delete “\(p.displayName)”?"
    }

    // MARK: - List column

    private var personaListColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    addPersona()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add persona (⌘N)")
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    duplicateSelection()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(selection.flatMap { store.persona(id: $0) } == nil)
                .help("Duplicate selected persona")

                Button {
                    if let id = selection, let p = store.persona(id: id) {
                        personaPendingDeletion = p
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selection.flatMap { store.persona(id: $0) } == nil)
                .help("Delete selected persona")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.top, 4)

            if store.personas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No personas yet", systemImage: "person.crop.circle.dashed")
                        .font(.subheadline.weight(.medium))
                    Text("Create one to switch Git identity from the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Add persona") {
                        addPersona()
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
                .padding(12)
            } else {
                List(selection: $selection) {
                    ForEach(store.personas) { p in
                        personaListRow(p)
                            .tag(Optional(p.id))
                            .contextMenu {
                                Button("Duplicate") {
                                    duplicatePersona(sourceID: p.id)
                                }
                                Divider()
                                Button("Delete…", role: .destructive) {
                                    personaPendingDeletion = p
                                }
                            }
                    }
                    .onMove { source, destination in
                        store.movePersonas(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func personaListRow(_ p: Persona) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.displayName.isEmpty ? "Untitled persona" : p.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(emailSubtitle(for: p))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private func emailSubtitle(for p: Persona) -> String {
        let e = p.gitUserEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.isEmpty { return "No email set" }
        return e
    }

    // MARK: - Editor column

    @ViewBuilder
    private var personaEditorColumn: some View {
        if let id = selection, store.persona(id: id) != nil {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    personaSummary(personaID: id)

                    SettingsForm {
                        LabeledContent("Name") {
                            TextField("Name", text: binding(\.displayName, for: id))
                                .focused($focusedField, equals: .displayName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    SettingsForm(
                        footer: emailFooterText(for: id)
                    ) {
                        LabeledContent("Git name") {
                            TextField("Ada Lovelace", text: binding(\.gitUserName, for: id))
                                .focused($focusedField, equals: .gitUserName)
                                .textContentType(.name)
                                .textFieldStyle(.roundedBorder)
                        }

                        LabeledContent("Git email") {
                            TextField("you@example.com", text: binding(\.gitUserEmail, for: id))
                                .focused($focusedField, equals: .gitEmail)
                                .textContentType(.emailAddress)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    SettingsForm(
                        footer: "Optional. Written to user.signingkey when you apply this persona."
                    ) {
                        LabeledContent("Signing key") {
                            TextField("e.g. ~/.ssh/id_ed25519.pub", text: optionalBinding(\.signingKey, for: id))
                                .focused($focusedField, equals: .signingKey)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    SettingsForm(
                        footer: "Private to this Mac; not sent to Git."
                    ) {
                        LabeledContent("Notes") {
                            TextField("Notes", text: optionalBinding(\.notes, for: id), axis: .vertical)
                                .focused($focusedField, equals: .notes)
                                .lineLimit(4...10)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
        } else {
            ContentUnavailableView {
                Label("Choose a persona", systemImage: "arrow.left")
            } description: {
                Text("Select an item in the list, or add a new persona.")
            } actions: {
                Button("Add persona") {
                    addPersona()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func emailFooterText(for id: UUID) -> String {
        let email = store.persona(id: id)?.gitUserEmail ?? ""
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Sets local or global user.email when you apply from the menu bar."
        }
        if !looksLikeEmail(trimmed) {
            return "This does not look like a typical email. Git will still accept it if you intend that."
        }
        return "Sets local or global user.email when you apply from the menu bar."
    }

    private func personaSummary(personaID: UUID) -> some View {
        let p = store.persona(id: personaID)
        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(p?.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (p?.displayName ?? "")
                    : "Untitled persona")
                    .font(.title3.weight(.semibold))

                Text(gitIdentityPreview(for: p))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func gitIdentityPreview(for p: Persona?) -> String {
        guard let p else { return "—" }
        let n = p.gitUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = p.gitUserEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty, e.isEmpty { return "Set Git author fields below" }
        if e.isEmpty { return n }
        if n.isEmpty { return e }
        return "\(n) <\(e)>"
    }

    private func addPersona() {
        let p = Persona(
            displayName: "New persona",
            gitUserName: "",
            gitUserEmail: ""
        )
        store.upsert(p)
        selection = p.id
        focusedField = .displayName
    }

    private func duplicateSelection() {
        guard let id = selection else { return }
        duplicatePersona(sourceID: id)
    }

    private func duplicatePersona(sourceID: UUID) {
        if let newID = store.duplicatePersona(id: sourceID) {
            selection = newID
            focusedField = .displayName
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Persona, String>, for id: UUID) -> Binding<String> {
        Binding(
            get: { store.persona(id: id)?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard var p = store.persona(id: id) else { return }
                p[keyPath: keyPath] = newValue
                store.upsert(p)
            }
        )
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<Persona, String?>, for id: UUID) -> Binding<String> {
        Binding(
            get: { store.persona(id: id)?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard var p = store.persona(id: id) else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                p[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
                store.upsert(p)
            }
        )
    }

    private func looksLikeEmail(_ s: String) -> Bool {
        let parts = s.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let domain = String(parts[1])
        return domain.contains(".") && domain.count >= 3
    }
}

// MARK: - About

struct AboutSettingsPane: View {
    private static let projectPageURL = URL(string: "https://github.com/erbilnas/git-persona")

    private var appDisplayName: String {
        let s = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? "GitPersona" : s
    }

    var body: some View {
        SettingsDetailScaffold(title: "About") {
            VStack(spacing: 16) {
                aboutHero

                SettingsForm {
                    LabeledContent("Version") {
                        Text(AppVersion.marketingVersion)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Build") {
                        Text(AppVersion.buildNumber)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String,
                       !copyright.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        LabeledContent("Copyright") {
                            Text(copyright)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                SettingsForm(
                    footer: "Switch Git author identity per repository or globally from the menu bar."
                ) {
                    Button("About GitPersona…") {
                        showAboutPanel()
                    }
                    .frame(maxWidth: .infinity)

                    if let url = Self.projectPageURL {
                        Button("Project on GitHub") {
                            NSWorkspace.shared.open(url)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var aboutHero: some View {
        VStack(spacing: 12) {
            brandLogoImage(size: 72)

            VStack(spacing: 4) {
                Text(appDisplayName)
                    .font(.system(size: 22, weight: .semibold))

                Text(AppVersion.fullDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)

        let credits = NSAttributedString(
            string: "Switch Git author identity per repository or globally from the menu bar.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    style.lineSpacing = 4
                    return style
                }()
            ]
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: appDisplayName,
            .applicationVersion: AppVersion.marketingVersion,
            .version: AppVersion.buildNumber,
            .credits: credits
        ])
    }
}

import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(PersonaStore.self) private var store
    @State private var selection: UUID?
    @State private var personaPendingDeletion: Persona?
    @State private var launchAtLoginRefresh = 0
    @State private var launchAtLoginError: String?
    @FocusState private var focusedField: SettingsFocusField?

    private enum SettingsFocusField: Hashable {
        case displayName
        case gitUserName
        case gitEmail
        case signingKey
        case notes
    }

    private static let projectPageURL = URL(string: "https://github.com/erbilnas/git-persona")

    var body: some View {
        NavigationSplitView {
            sidebarList
        } detail: {
            detailPane
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        .frame(minWidth: 640, minHeight: 460)
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
        .alert("Open at login", isPresented: Binding(
            get: { launchAtLoginError != nil },
            set: { if !$0 { launchAtLoginError = nil } }
        )) {
            Button("OK", role: .cancel) { launchAtLoginError = nil }
        } message: {
            Text(launchAtLoginError ?? "")
        }
    }

    private var deleteDialogTitle: String {
        guard let p = personaPendingDeletion else { return "" }
        return "Delete “\(p.displayName)”?"
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

    private var appDisplayName: String {
        let s = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? "GitPersona" : s
    }

    /// Single scrollable sidebar: avoids VStack + List flex bugs and clipped “About”.
    private var sidebarList: some View {
        List(selection: $selection) {
            Section {
                Group {
                    Toggle("Open at login", isOn: openAtLoginBinding)
                        .help("Launch GitPersona when you log in to this Mac.")

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
                .id(launchAtLoginRefresh)
            } header: {
                Text("General")
            }

            Section {
                if store.personas.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("No personas yet", systemImage: "person.crop.circle.dashed")
                            .font(.subheadline.weight(.medium))
                        Text("Create one to switch Git name, email, and signing options from the menu bar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Add persona") {
                            addPersona()
                        }
                        .keyboardShortcut("n", modifiers: .command)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(store.personas) { p in
                        personaSidebarRow(p)
                            .tag(Optional(p.id))
                            .listRowInsets(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8))
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
            } header: {
                Text("Saved personas")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(decorative: "BrandLogo")
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(appDisplayName)
                                .font(.headline)
                            Text(AppVersion.fullDescription)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Switch Git author identity per repository or globally from the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String,
                       !copyright.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(copyright)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let url = Self.projectPageURL {
                        Link(destination: url) {
                            Label("Project on GitHub", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text("About")
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 52)
        .navigationTitle("GitPersona")
        .onAppear { launchAtLoginRefresh += 1 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLoginRefresh += 1
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    addPersona()
                } label: {
                    Label("Add persona", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Create a new persona (⌘N)")

                Button {
                    duplicateSelection()
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                .disabled(selection.flatMap { store.persona(id: $0) } == nil)
                .help("Duplicate the selected persona")
            }
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    if let id = selection, let p = store.persona(id: id) {
                        personaPendingDeletion = p
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selection.flatMap { store.persona(id: $0) } == nil)
                .help("Delete the selected persona")
            }
        }
    }

    private func personaSidebarRow(_ p: Persona) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.displayName.isEmpty ? "Untitled persona" : p.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(emailSubtitle(for: p))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private func emailSubtitle(for p: Persona) -> String {
        let e = p.gitUserEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.isEmpty {
            return "No email set"
        }
        return e
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selection, store.persona(id: id) != nil {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    personaSummary(personaID: id)

                    Form {
                        Section {
                            TextField("Name", text: binding(\.displayName, for: id))
                                .focused($focusedField, equals: .displayName)
                                .textFieldStyle(.roundedBorder)
                        } header: {
                            Text("Label")
                        } footer: {
                            Text("Shown only inside GitPersona to tell personas apart.")
                        }

                        Section {
                            TextField("Ada Lovelace", text: binding(\.gitUserName, for: id))
                                .focused($focusedField, equals: .gitUserName)
                                .textContentType(.name)
                                .textFieldStyle(.roundedBorder)

                            TextField("you@example.com", text: binding(\.gitUserEmail, for: id))
                                .focused($focusedField, equals: .gitEmail)
                                .textContentType(.emailAddress)
                                .textFieldStyle(.roundedBorder)
                        } header: {
                            Text("Git author")
                        } footer: {
                            emailFooter(for: id)
                        }

                        Section {
                            TextField("e.g. ~/.ssh/id_ed25519.pub or key fingerprint", text: optionalBinding(\.signingKey, for: id))
                                .focused($focusedField, equals: .signingKey)
                                .textFieldStyle(.roundedBorder)
                        } header: {
                            Text("Signing key")
                        } footer: {
                            Text("Optional. Written to user.signingkey when you apply this persona.")
                        }

                        Section {
                            TextField("Notes", text: optionalBinding(\.notes, for: id), axis: .vertical)
                                .focused($focusedField, equals: .notes)
                                .lineLimit(4...10)
                                .textFieldStyle(.roundedBorder)
                        } header: {
                            Text("Notes")
                        } footer: {
                            Text("Private to this Mac; not sent to Git.")
                        }
                    }
                    .formStyle(.grouped)
                    .padding(.bottom, 8)
                }
                .padding()
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Persona")
            .navigationSubtitle(store.persona(id: id)?.displayName ?? "")
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
        }
    }

    @ViewBuilder
    private func emailFooter(for id: UUID) -> some View {
        let email = store.persona(id: id)?.gitUserEmail ?? ""
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text("Sets local or global user.email when you apply from the menu bar.")
        } else if !Self.looksLikeEmail(trimmed) {
            Label {
                Text("This does not look like a typical email. Git will still accept it if you intend that.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
            }
            .font(.footnote)
        } else {
            Text("Sets local or global user.email when you apply from the menu bar.")
        }
    }

    private func personaSummary(personaID: UUID) -> some View {
        let p = store.persona(id: personaID)
        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(p?.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (p?.displayName ?? "")
                    : "Untitled persona")
                    .font(.title2.weight(.semibold))

                Text(gitIdentityPreview(for: p))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func gitIdentityPreview(for p: Persona?) -> String {
        guard let p else { return "—" }
        let n = p.gitUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = p.gitUserEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty, e.isEmpty {
            return "Set Git author fields below"
        }
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

    private static func looksLikeEmail(_ s: String) -> Bool {
        let parts = s.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let domain = String(parts[1])
        return domain.contains(".") && domain.count >= 3
    }
}
